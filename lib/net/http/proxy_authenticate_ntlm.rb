require "net/http/proxy_authenticate_ntlm/version"

require "net/http"
require "net/https"
require "net/ntlm"
require "kconv"

# monkey patching Net::NTLM
class << Net::NTLM
  def apply_des(plain, keys)
    dec = OpenSSL::Cipher::DES.new
    keys.map {|k|
      dec.encrypt
      dec.key = k
      dec.update(plain)
    }
  end
end

module Net
  class HTTP
    module ProxyAuthenticateNTLM
      def self.enabled?
        @enabled
      end

      def self.enabled=(v)
        @enabled = !!v
      end

      self.enabled = false

      def request(req, body = nil, &block)  # :yield: +response+
        return super unless ProxyAuthenticateNTLM.enabled?

        unless started?
          start {
            req['connection'] ||= 'close'
            return request(req, body, &block)
          }
        end

        req.set_body_internal body
        res = transport_request(req, &block)
        if sspi_auth?(res)
          sspi_auth(req)
          res = transport_request(req, &block)
        elsif ntlm_auth?(res)
          ntlm_auth(req)
          res = transport_request(req, &block)
        end
        res
      end


      def connect
        return super unless ProxyAuthenticateNTLM.enabled?

        if proxy? then
          conn_address = proxy_address
          conn_port    = proxy_port
        else
          conn_address = address
          conn_port    = port
        end

        D "opening connection to #{conn_address}:#{conn_port}..."
        s = Timeout.timeout(@open_timeout, Net::OpenTimeout) {
          begin
            TCPSocket.open(conn_address, conn_port, @local_host, @local_port)
          rescue => e
            raise e, "Failed to open TCP connection to " +
              "#{conn_address}:#{conn_port} (#{e.message})"
          end
        }
        s.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
        D "opened"
        if use_ssl?
          ssl_parameters = Hash.new
          iv_list = instance_variables
          SSL_IVNAMES.each_with_index do |ivname, i|
            if iv_list.include?(ivname) and
              value = instance_variable_get(ivname)
              ssl_parameters[SSL_ATTRIBUTES[i]] = value if value
            end
          end
          @ssl_context = OpenSSL::SSL::SSLContext.new
          @ssl_context.set_params(ssl_parameters)
          D "starting SSL for #{conn_address}:#{conn_port}..."
          s = OpenSSL::SSL::SSLSocket.new(s, @ssl_context)
          s.sync_close = true
          D "SSL established"
        end
        @socket = BufferedIO.new(s)
        @socket.read_timeout = @read_timeout
        @socket.continue_timeout = @continue_timeout
        @socket.debug_output = @debug_output
        if use_ssl?
          begin
            if proxy?
              connect_proxy
            end
            # Server Name Indication (SNI) RFC 3546
            s.hostname = @address if s.respond_to? :hostname=
            if @ssl_session and
               Process.clock_gettime(Process::CLOCK_REALTIME) < @ssl_session.time.to_f + @ssl_session.timeout
              s.session = @ssl_session if @ssl_session
            end
            if timeout = @open_timeout
              while true
                raise Net::OpenTimeout if timeout <= 0
                start = Process.clock_gettime Process::CLOCK_MONOTONIC
                # to_io is required because SSLSocket doesn't have wait_readable yet
                case s.connect_nonblock(exception: false)
                when :wait_readable; s.to_io.wait_readable(timeout)
                when :wait_writable; s.to_io.wait_writable(timeout)
                else; break
                end
                timeout -= Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
              end
            else
              s.connect
            end
            if @ssl_context.verify_mode != OpenSSL::SSL::VERIFY_NONE
              s.post_connection_check(@address)
            end
            @ssl_session = s.session
          rescue => exception
            D "Conn close because of connect error #{exception}"
            @socket.close if @socket and not @socket.closed?
            raise exception
          end
        end
        on_connect
      end

      private
      def ntlm_auth?(res)
        proxy_user && res.code.to_i == 407 && Array(res["Proxy-Authenticate"]).include?("NTLM")
      end

      def ntlm_auth(req)
        negotiate_message = Net::NTLM::Message::Type1.new

        req["Proxy-Authorization"] = "NTLM #{Base64.strict_encode64(negotiate_message.serialize)}"
        req["Connection"] = "Keep-Alive"
        req["Proxy-Connection"] = "Keep-Alive"
        negotiate_response = transport_request(req)
        authphrase = negotiate_response["Proxy-Authenticate"] or return res

        challenge_message = Net::NTLM::Message::Type2.parse(Base64.strict_decode64(authphrase.gsub(/^NTLM /, "")))
        authenticate_message = challenge_message.response(parse_proxy_user(proxy_user).merge(password: proxy_pass))

        req["Proxy-Authorization"] = "NTLM #{Base64.strict_encode64(authenticate_message.serialize)}"
      end

      def connect_proxy
        buf = "CONNECT #{@address}:#{@port} HTTP/#{HTTPVersion}\r\n"
        buf << "Host: #{@address}:#{@port}\r\n"

        if proxy_user
          credential = ["#{proxy_user}:#{proxy_pass}"].pack('m')
          credential.delete!("\r\n")
          buf << "Proxy-Authorization: Basic #{credential}\r\n"
        end

        buf << "\r\n"
        @socket.write(buf)
        HTTPResponse.read_new(@socket).value
      rescue Net::HTTPServerException
        if ntlm_auth?($!.response)
          @socket.read($!.response["Content-Length"].to_i)
          connect_proxy_with_ntlm_auth
        else
          raise
        end
      end

      def connect_proxy_with_ntlm_auth
        negotiate_message = Net::NTLM::Message::Type1.new

        @socket.write([
          "CONNECT #{@address}:#{@port} HTTP/#{HTTPVersion}",
          "Host: #{@address}:#{@port}",
          "Proxy-Authorization: NTLM #{Base64.strict_encode64(negotiate_message.serialize)}",
          "Proxy-Connection: Keep-Alive",
        ].join("\r\n") + "\r\n\r\n")

        res = HTTPResponse.read_new(@socket)

        begin
          res.value
        rescue Net::HTTPClientException
          unless $!.response.code.to_i == 407
            raise
          end
          if res["Content-Length"]
            @socket.read(res["Content-Length"].to_i)
          end
        end

        challenge_message = Net::NTLM::Message::Type2.parse(Base64.decode64(res["Proxy-Authenticate"].gsub(/^NTLM /, "")))
        authenticate_message = challenge_message.response(parse_proxy_user(proxy_user).merge(password: proxy_pass))

        @socket.write([
          "CONNECT #{@address}:#{@port} HTTP/#{HTTPVersion}",
          "Host: #{@address}:#{@port}",
          "Proxy-Authorization: NTLM #{Base64.strict_encode64(authenticate_message.serialize)}",
          "Proxy-Connection: Keep-Alive",
        ].join("\r\n") + "\r\n\r\n")
        HTTPResponse.read_new(@socket).value
      end

      # Returns {user: user, domain: domain}
      def parse_proxy_user(proxy_user)
        case proxy_user
        when /(.+?)\\(.+)/ # domain\user
          {user: $2, domain: $1}
        when /(.+?)@(.+)/ # user@domain
          {user: $1, domain: $2}
        else
          {user: proxy_user}
        end
      end
    end
  end
end

Net::HTTP.prepend(Net::HTTP::ProxyAuthenticateNTLM)

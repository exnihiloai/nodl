module Nodl
  module Integrity
    module DerEncoding
      SHA256_OID = "2.16.840.1.101.3.4.2.1".freeze

      module_function

      def rfc3161_timestamp_request(digest:, hash_algorithm:, nonce:)
        raise ArgumentError, "Unsupported hash algorithm: #{hash_algorithm}" unless hash_algorithm == "sha256"

        algorithm_identifier = sequence(oid(SHA256_OID), null)
        message_imprint = sequence(algorithm_identifier, octet_string(digest))

        sequence(
          integer(1),
          message_imprint,
          integer(nonce),
          boolean(true)
        )
      end

      def rfc3161_response_status(response_der)
        top_tag, top_start, top_end, = read_tlv(response_der, 0)
        raise ArgumentError, "Timestamp response is not a DER sequence" unless top_tag == 0x30

        content = response_der.byteslice(top_start...top_end)
        status_tag, status_start, status_end, next_offset = read_tlv(content, 0)
        raise ArgumentError, "Timestamp response missing PKIStatusInfo sequence" unless status_tag == 0x30

        status_content = content.byteslice(status_start...status_end)
        int_tag, int_start, int_end, = read_tlv(status_content, 0)
        raise ArgumentError, "Timestamp response missing PKIStatus integer" unless int_tag == 0x02

        status = status_content.byteslice(int_start...int_end).unpack1("H*").to_i(16)
        [ status, next_offset < content.bytesize ]
      end

      def sequence(*elements)
        content = elements.join
        "\x30".b + length(content.bytesize) + content
      end

      def integer(value)
        raise ArgumentError, "DER integer must be non-negative" if value.negative?

        content = if value.zero?
          "\x00".b
        else
          hex = value.to_s(16)
          hex = "0#{hex}" if hex.length.odd?
          bytes = [ hex ].pack("H*")
          bytes.getbyte(0) & 0x80 == 0x80 ? "\x00".b + bytes : bytes
        end

        "\x02".b + length(content.bytesize) + content
      end

      def boolean(value)
        "\x01\x01".b + (value ? "\xFF".b : "\x00".b)
      end

      def null
        "\x05\x00".b
      end

      def octet_string(value)
        "\x04".b + length(value.bytesize) + value
      end

      def oid(dotted)
        parts = dotted.split(".").map(&:to_i)
        raise ArgumentError, "Invalid OID" if parts.length < 2

        body = [ (40 * parts[0]) + parts[1] ]
        parts.drop(2).each do |number|
          if number.zero?
            body << 0
            next
          end

          encoded = []
          current = number
          while current.positive?
            encoded << (current & 0x7F)
            current >>= 7
          end
          encoded.reverse_each.with_index do |chunk, index|
            body << (index == encoded.length - 1 ? chunk : (0x80 | chunk))
          end
        end

        payload = body.pack("C*")
        "\x06".b + length(payload.bytesize) + payload
      end

      def length(value)
        return value.chr.b if value < 0x80

        bytes = []
        current = value
        while current.positive?
          bytes << (current & 0xFF)
          current >>= 8
        end
        encoded = bytes.reverse.pack("C*")
        (0x80 | encoded.bytesize).chr.b + encoded
      end

      def read_tlv(data, offset)
        raise ArgumentError, "Unexpected end of DER payload" if offset >= data.bytesize

        tag = data.getbyte(offset)
        index = offset + 1
        raise ArgumentError, "Invalid DER length" if index >= data.bytesize

        first_length = data.getbyte(index)
        index += 1
        value_length = if first_length & 0x80 == 0x80
          count = first_length & 0x7F
          raise ArgumentError, "Invalid DER long length" if count.zero? || index + count > data.bytesize

          bytes = data.byteslice(index, count)
          index += count
          bytes.unpack1("H*").to_i(16)
        else
          first_length
        end

        value_start = index
        value_end = value_start + value_length
        raise ArgumentError, "DER value exceeds payload size" if value_end > data.bytesize

        [ tag, value_start, value_end, value_end ]
      end
    end
  end
end

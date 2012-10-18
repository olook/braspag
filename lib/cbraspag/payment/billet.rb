require "bigdecimal"

module Braspag
  class Connection
    
    MAPPING_BILLET = {
      :merchant_id => "merchantId",
      :order_id => "orderId",
      :customer_name => "customerName",
      :customer_id => "customerIdNumber",
      :amount => "amount",
      :payment_method => "paymentMethod",
      :number => "boletoNumber",
      :instructions => "instructions",
      :expiration_date => "expirationDate",
      :emails => "emails"
    }
    
    def generate_billet(order, billet)
      return ::Response.new
      
      connection = Braspag::Connection.instance
      params[:merchant_id] = connection.merchant_id

      params = self.normalize_params(params)
      self.check_params(params)

      data = {}

      MAPPING.each do |k, v|
        case k
        when :payment_method
          data[v] = PAYMENT_METHODS[params[:payment_method]]
        when :amount
          data[v] = Utils.convert_decimal_to_string(params[:amount])
        else
          data[v] = params[k] || ""
        end
      end

      request = ::HTTPI::Request.new(self.creation_url)
      request.body = data

      response = Utils::convert_to_map(::HTTPI.post(request).body,
        {
          :url => nil,
          :amount => nil,
          :number => "boletoNumber",
          :expiration_date => Proc.new { |document|
            begin
              Date.parse(document.search("expirationDate").first.to_s)
            rescue
              nil
            end
          },
          :return_code => "returnCode",
          :status => nil,
          :message => nil
        })

      raise InvalidMerchantId if response[:message] == "Invalid merchantId"
      raise InvalidAmount if response[:message] == "Invalid purchase amount"
      raise InvalidPaymentMethod if response[:message] == "Invalid payment method"
      raise InvalidStringFormat if response[:message] == "Input string was not in a correct format."
      raise UnknownError if response[:status].nil?

      response[:amount] = BigDecimal.new(response[:amount])

      response
    end
    
  end
  
  class Billet
    include ::ActiveAttr::Model
    
    class DueDateValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        unless (
          value.kind_of?(Time) || value.kind_of?(Date)
        )
          record.errors.add attribute, "invalid date"
        end
      end
    end
    
    attr_accessor :id, :instructions, :due_date_on

    validates :id, :length => {:minimum => 1, :maximum => 255, :on => :generate, :allow_blank => true }
    validates :instructions, :length => {:minimum => 1, :maximum => 512, :on => :generate, :allow_blank => true }
    validates :due_date_on, :presence => { :on => :generate }
    validates :due_date_on, :due_date => { :on => :generate }
    
  end
end

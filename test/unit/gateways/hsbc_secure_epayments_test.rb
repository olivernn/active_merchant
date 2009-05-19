require File.dirname(__FILE__) + '/../../test_helper'

class HsbcSecureEpaymentTest < Test::Unit::TestCase
  def setup
    ActiveMerchant::Billing::Base.mode = :test
    
    @gateway = ActiveMerchant::Billing::HsbcSecureEpaymentGateway.new(
                 :login => 'login',
                 :password => 'password',
                 :client_id => 'client_id'
               )

    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
    @authorization = '483e6382-7d13-3001-002b-0003bac00fc9'
  end
  
  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    
    # Replace with authorization number from the successful response
    assert_equal '483e6382-7d13-3001-002b-0003bac00fc9', response.authorization
    assert response.test?
  end

  def test_unsuccessful_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    
    assert response = @gateway.capture(@amount, @authorization, @options)
    assert_success response
    
    # Replace with authorization number from the successful response
    assert_equal '483e6382-7d13-3001-002b-0003bac00fc9', response.authorization
    assert response.test?
    
    assert_equal 1, response.params["return_code"]
    assert_equal "Approved.", response.params["return_message"]
    assert_equal "A", response.params["transaction_status"]
    assert_equal "483e6382-7d13-3001-002b-0003bac00fc9", response.authorization
    assert_equal "797220", response.params["auth_code"]
  end

  def test_unsuccessful_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)
    
    assert response = @gateway.capture(@amount, @authorization, @options)
    assert_failure response
    assert response.test?
    
    assert_equal 1067, response.params["return_code"]
    assert_equal "Denied.", response.params["return_message"]
    assert_equal "E", response.params["transaction_status"]
    assert_equal "483e6382-7d13-3001-002b-0003bac00fc9", response.authorization
    assert_nil response.params["auth_code"]
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(failed_avs_result_no_matches)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    
  end
  
  def test_cvv_result
    
  end

  private
  
  # Place raw successful response from gateway here
  def successful_authorize_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <EngineDocList>
     <DocVersion DataType="String">1.0</DocVersion>
     <EngineDoc>
      <Overview>
       <AuthCode DataType="String">889350</AuthCode>
       <CcErrCode DataType="S32">1</CcErrCode>
       <CcReturnMsg DataType="String">Approved.</CcReturnMsg>
       <DateTime DataType="DateTime">1212066788586</DateTime>
       <Mode DataType="String">Y</Mode>
       <OrderId DataType="String">483e6382-7d12-3001-002b-0003bac00fc9</OrderId>
       <TransactionId DataType="String">483e6382-7d13-3001-002b-0003bac00fc9</TransactionId>
       <TransactionStatus DataType="String">A</TransactionStatus>
      </Overview>
     </EngineDoc>
    </EngineDocList>
    XML
  end
  
  # Place raw failed response from gateway here
  def failed_authorize_response
    <<-XML
    <EngineDocList>
     <DocVersion DataType="String">1.0</DocVersion>
     <EngineDoc>
      <OrderFormDoc>
       <Id DataType="String">48b7024c-0322-3002-002a-0003ba9a87ff</Id>
       <Mode DataType="String">Y</Mode>
       <Transaction>
        <Id DataType="String">48b7024c-0323-3002-002a-0003ba9a87ff</Id>
        <Type DataType="String">PreAuth</Type>
       </Transaction>
      </OrderFormDoc>
      <Overview>
       <CcErrCode DataType="S32">1067</CcErrCode>
       <CcReturnMsg DataType="String">System error.</CcReturnMsg>
       <DateTime DataType="DateTime">1219953701297</DateTime>
       <Mode DataType="String">Y</Mode>
       <Notice DataType="String">Unable to determine card type. (&apos;length&apos; is &apos;16&apos;)</Notice>
       <TransactionId DataType="String">48b7024c-0323-3002-002a-0003ba9a87ff</TransactionId>
       <TransactionStatus DataType="String">E</TransactionStatus>
      </Overview>
     </EngineDoc>
    </EngineDocList>
    XML
  end
  
  def successful_capture_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <EngineDocList>
     <DocVersion DataType="String">1.0</DocVersion>
     <EngineDoc>
      <OrderFormDoc>
       <DateTime DataType="DateTime">1219956808155</DateTime>
       <Id DataType="String">483e6382-7d13-3001-002b-0003bac00fc9</Id>
       <Mode DataType="String">Y</Mode>
       <Transaction>
        <AuthCode DataType="String">797220</AuthCode>
        <CardProcResp>
         <CcErrCode DataType="S32">1</CcErrCode>
         <CcReturnMsg DataType="String">Approved.</CcReturnMsg>
         <Status DataType="String">1</Status>
        </CardProcResp>
        <Id DataType="String">483e6382-7d13-3001-002b-0003bac00fc9</Id>
        <Type DataType="String">PostAuth</Type>
       </Transaction>
      </OrderFormDoc>
      <Overview>
       <AuthCode DataType="String">797220</AuthCode>
       <CcErrCode DataType="S32">1</CcErrCode>
       <CcReturnMsg DataType="String">Approved.</CcReturnMsg>
       <DateTime DataType="DateTime">1219956808155</DateTime>
       <Mode DataType="String">Y</Mode>
       <TransactionId DataType="String">483e6382-7d13-3001-002b-0003bac00fc9</TransactionId>
       <TransactionStatus DataType="String">A</TransactionStatus>
      </Overview>
     </EngineDoc>
    </EngineDocList>
    XML
  end

  def failed_capture_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <EngineDocList>
     <DocVersion DataType="String">1.0</DocVersion>
     <EngineDoc>
      <OrderFormDoc>
       <Id DataType="String">483e6382-7d13-3001-002b-0003bac00fc9</Id>
       <Mode DataType="String">Y</Mode>
       <Transaction>
        <CardProcResp>
         <CcErrCode DataType="S32">1067</CcErrCode>
         <CcReturnMsg DataType="String">Denied.</CcReturnMsg>
         <Status DataType="String">1</Status>
        </CardProcResp>
        <Id DataType="String">483e6382-7d13-3001-002b-0003bac00fc9</Id>
        <Type DataType="String">PostAuth</Type>
       </Transaction>
      </OrderFormDoc>
      <Overview>
       <CcErrCode DataType="S32">1067</CcErrCode>
       <CcReturnMsg DataType="String">Denied.</CcReturnMsg>
       <DateTime DataType="DateTime">1219956808155</DateTime>
       <Mode DataType="String">Y</Mode>
       <TransactionId DataType="String">483e6382-7d13-3001-002b-0003bac00fc9</TransactionId>
       <TransactionStatus DataType="String">E</TransactionStatus>
      </Overview>
     </EngineDoc>
    </EngineDocList>
    XML
  end
  
  def failed_avs_result_no_matches
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <EngineDocList>
     <DocVersion DataType="String">1.0</DocVersion>
     <EngineDoc>
       <OrderFormDoc>
        <Overview>
          <AvsDisplay>NN</AvsDisplay>
        </Overview>
       </OrderFormDoc>
      <Overview>
       <AuthCode DataType="String">889350</AuthCode>
       <CcErrCode DataType="S32">1</CcErrCode>
       <CcReturnMsg DataType="String">Approved.</CcReturnMsg>
       <Mode DataType="String">Y</Mode>
       <TransactionId DataType="String">483e6382-7d13-3001-002b-0003bac00fc9</TransactionId>
       <TransactionStatus DataType="String">A</TransactionStatus>
      </Overview>
     </EngineDoc>
    </EngineDocList>
    XML
  end
  
  def failed_cvv_result
    
  end
end

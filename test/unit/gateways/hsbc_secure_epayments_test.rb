require File.dirname(__FILE__) + '/../../test_helper'

class HsbcSecureEpaymentTest < Test::Unit::TestCase
  def setup
    ActiveMerchant::Billing::Base.mode = :test
    
    @gateway = ActiveMerchant::Billing::HsbcSecureEpaymentsGateway.new(
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
  
  def test_invalid_credentials_rejected
    @gateway.expects(:ssl_post).returns(auth_fail_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal response.message, "Insufficient permissions to perform requested operation."
  end
  
  def test_fraudulent_transaction_avs
    @gateway.expects(:ssl_post).returns(avs_result("NN", "500"))
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.fraud_review?

    @gateway.expects(:ssl_post).returns(avs_result("NN", "501"))
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.fraud_review?

    @gateway.expects(:ssl_post).returns(avs_result("NN", "502"))
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.fraud_review?
  end
  
  def test_fraudulent_transaction_cvv
    @gateway.expects(:ssl_post).returns(cvv_result("NN", "1055"))
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.fraud_review?
  end
  
  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '483e6382-7d13-3001-002b-0003bac00fc9', response.authorization
    assert_equal '483e6382-7d12-3001-002b-0003bac00fc9', response.order_id
    assert response.test?
  end

  def test_unsuccessful_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    # copied from the successful response below
    authcode = '4bd93722-c8b4-3003-002a-0003bac62f71'

    assert_success @gateway.void(authcode, :currency => 'GBP', :money => 1)
  end

  def test_unsuccessful_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    # copied from the successful response below
    authcode = '4bd93722-c8b4-3003-002a-0003bac62f71'

    assert_failure @gateway.void(authcode, :currency => 'GBP', :money => 1)
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
  
  def test_avs_result_success
    @gateway.expects(:ssl_post).returns(avs_result("YY"))
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "Y", response.avs_result['code']
    assert_equal "Y", response.avs_result['street_match']
    assert_equal "Y", response.avs_result['postal_match']
  end

  def test_avs_result_fail_no_street_match
    @gateway.expects(:ssl_post).returns(avs_result("NY"))
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "W", response.avs_result['code']
    assert_equal "N", response.avs_result['street_match']
    assert_equal "Y", response.avs_result['postal_match']
  end

  def test_avs_result_fail_no_postal_match
    @gateway.expects(:ssl_post).returns(avs_result("YN"))
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "A", response.avs_result['code']
    assert_equal "Y", response.avs_result['street_match']
    assert_equal "N", response.avs_result['postal_match']
  end

  def test_avs_result_fail_no_match
    @gateway.expects(:ssl_post).returns(avs_result("NN"))
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "C", response.avs_result['code']
    assert_equal "N", response.avs_result['street_match']
    assert_equal "N", response.avs_result['postal_match']
  end
  
  def test_avs_result_fail_no_postal_match
    @gateway.expects(:ssl_post).returns(avs_result("YN"))
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "A", response.avs_result['code']
    assert_equal "Y", response.avs_result['street_match']
    assert_equal "N", response.avs_result['postal_match']
  end

  def test_cvv_result_success
    @gateway.expects(:ssl_post).returns(cvv_result("1"))
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "M", response.cvv_result['code']
  end

  def test_cvv_result_fail_no_match
    @gateway.expects(:ssl_post).returns(cvv_result("2"))
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "N", response.cvv_result['code']
  end

  def test_cvv_result_fail_not_processed
    @gateway.expects(:ssl_post).returns(cvv_result("3"))
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "P", response.cvv_result['code']
  end
  
  def test_cvv_result_fail_not_present
    @gateway.expects(:ssl_post).returns(cvv_result("4"))
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "S", response.cvv_result['code']
  end
  
  def test_cvv_result_fail_invalid
    @gateway.expects(:ssl_post).returns(cvv_result("6"))
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "I", response.cvv_result['code']
  end
  
  def test_cvv_result_fail_not_supported
    @gateway.expects(:ssl_post).returns(cvv_result("0"))
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "X", response.cvv_result['code']

    @gateway.expects(:ssl_post).returns(cvv_result("5"))
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "X", response.cvv_result['code']
  end
  
  def test_cvv_result_fail_issuer_unable_to_process
    @gateway.expects(:ssl_post).returns(cvv_result("7"))
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "U", response.cvv_result['code']
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
  
  def avs_result(avs_display, cc_err_code = '1')
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <EngineDocList>
      <DocVersion DataType="String">1.0</DocVersion>
      <EngineDoc>
        <OrderFormDoc>
          <Transaction>
            <CardProcResp>
              <AvsDisplay>#{avs_display}</AvsDisplay>
            </CardProcResp>
          </Transaction>
        </OrderFormDoc>
        <Overview>
          <CcErrCode DataType="S32">#{cc_err_code}</CcErrCode>
          <CcReturnMsg DataType="String">Approved.</CcReturnMsg>
          <Mode DataType="String">Y</Mode>
          <TransactionStatus DataType="String">A</TransactionStatus>
        </Overview>
      </EngineDoc>
    </EngineDocList>
    XML
  end
  
  def cvv_result(cvv2_resp, cc_err_code = '1')
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <EngineDocList>
      <DocVersion DataType="String">1.0</DocVersion>
      <EngineDoc>
        <OrderFormDoc>
          <Transaction>
            <CardProcResp>
              <Cvv2Resp>#{cvv2_resp}</Cvv2Resp>
            </CardProcResp>
          </Transaction>
        </OrderFormDoc>
        <Overview>
          <CcErrCode DataType="S32">#{cc_err_code}</CcErrCode>
          <CcReturnMsg DataType="String">Approved.</CcReturnMsg>
          <Mode DataType="String">Y</Mode>
          <TransactionStatus DataType="String">A</TransactionStatus>
        </Overview>
      </EngineDoc>
    </EngineDocList>
    XML
  end
  
  def auth_fail_response
    <<-XML
    <?xml version='1.0' encoding='UTF-8'?>
    <EngineDocList>
     <DocVersion DataType='String'>1.0</DocVersion>
     <EngineDoc>
      <MessageList>
       <MaxSev DataType='S32'>6</MaxSev>
       <Message>
        <AdvisedAction DataType='S32'>16</AdvisedAction>
        <Audience DataType='String'>Merchant</Audience>
        <ResourceId DataType='S32'>7</ResourceId>
        <Sev DataType='S32'>6</Sev>
        <Text DataType='String'>Insufficient permissions to perform requested operation.</Text>
       </Message>
      </MessageList>
     </EngineDoc>
    </EngineDocList>
    XML
  end

  def successful_void_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <EngineDocList>
      <DocVersion DataType="String">1.0</DocVersion>
      <EngineDoc>
        <OrderFormDoc>
          <Consumer>
            <PaymentMech>
              <CreditCard>
                <ExchangeType DataType="S32">1</ExchangeType>
              </CreditCard>
              <Type DataType="String">CreditCard</Type>
            </PaymentMech>
          </Consumer>
          <DateTime DataType="DateTime">1272558106928</DateTime>
          <Id DataType="String">4bd93722-c8b4-3003-002a-0003bac62f71</Id>
          <Mode DataType="String">Y</Mode>
          <Transaction>
            <AuthCode DataType="String">506017</AuthCode>
            <CardProcResp>
              <CcErrCode DataType="S32">1</CcErrCode>
              <CcReturnMsg DataType="String">Approved.</CcReturnMsg>
              <ProcReturnCode DataType="String">1</ProcReturnCode>
              <ProcReturnMsg DataType="String">Approved</ProcReturnMsg>
              <Status DataType="String">1</Status>
            </CardProcResp>
            <CardholderPresentCode DataType="S32">7</CardholderPresentCode>
            <ChargeTypeCode DataType="String">S</ChargeTypeCode>
            <CurrentTotals>
              <Totals>
                <Total DataType="Money" Currency="826">1</Total>
              </Totals>
            </CurrentTotals>
            <Id DataType="String">4bd93722-c8b5-3003-002a-0003bac62f71</Id>
            <InputEnvironment DataType="S32">4</InputEnvironment>
            <ReviewPendFlag DataType="S32">0</ReviewPendFlag>
            <SecurityIndicator DataType="S32">7</SecurityIndicator>
            <TerminalInputCapability DataType="S32">1</TerminalInputCapability>
            <Type DataType="String">Void</Type>
          </Transaction>
        </OrderFormDoc>
        <Overview>
          <AuthCode DataType="String">506017</AuthCode>
          <CcErrCode DataType="S32">1</CcErrCode>
          <CcReturnMsg DataType="String">Approved.</CcReturnMsg>
          <DateTime DataType="DateTime">1272558106928</DateTime>
          <Mode DataType="String">Y</Mode>
          <OrderId DataType="String">4bd93722-c8b4-3003-002a-0003bac62f71</OrderId>
          <TransactionId DataType="String">4bd93722-c8b5-3003-002a-0003bac62f71</TransactionId>
          <TransactionStatus DataType="String">A</TransactionStatus>
        </Overview>
      </EngineDoc>
    </EngineDocList>
    XML
  end

  def failed_void_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <EngineDocList>
      <DocVersion DataType="String">1.0</DocVersion>
      <EngineDoc>
        <ContentType DataType="String">OrderFormDoc</ContentType>
        <DocumentId DataType="String">4bd93722-c978-3003-002a-0003bac62f71</DocumentId>
        <Instructions>
          <Pipeline DataType="String">Payment</Pipeline>
        </Instructions>
        <MessageList>
          <MaxSev DataType="S32">6</MaxSev>
          <Message>
            <AdvisedAction DataType="S32">16</AdvisedAction>
            <Audience DataType="String">Merchant</Audience>
            <Component DataType="String">CcxOcc</Component>
            <ContextId DataType="String">PaymentDba</ContextId>
            <DataState DataType="S32">3</DataState>
            <FileLine DataType="S32">498</FileLine>
            <FileName DataType="String">CcxOccExecute.cpp</FileName>
            <FileTime DataType="String">15:18:59Oct 13 2007</FileTime>
            <ResourceId DataType="S32">13</ResourceId>
            <Sev DataType="S32">6</Sev>
            <Text DataType="String">The combination of transaction 'auth_response.authorization' and processing mode 'Y' was not found.</Text>
          </Message>
        </MessageList>
        <OrderFormDoc>
          <Consumer>
            <PaymentMech>
              <Type DataType="String">CreditCard</Type>
            </PaymentMech>
          </Consumer>
          <DateTime DataType="DateTime">1272558214310</DateTime>
          <Mode DataType="String">Y</Mode>
          <Transaction>
            <CurrentTotals>
              <Totals>
                <Total DataType="Money" Currency="826">1</Total>
              </Totals>
            </CurrentTotals>
            <Id DataType="String">auth_response.authorization</Id>
            <Type DataType="String">Void</Type>
          </Transaction>
        </OrderFormDoc>
        <Overview>
          <CcErrCode DataType="S32">1067</CcErrCode>
          <CcReturnMsg DataType="String">System error.</CcReturnMsg>
          <DateTime DataType="DateTime">1272558214310</DateTime>
          <Mode DataType="String">Y</Mode>
          <Notice DataType="String">The combination of transaction 'auth_response.authorization' and processing mode 'Y' was not found.</Notice>
          <TransactionId DataType="String">auth_response.authorization</TransactionId>
          <TransactionStatus DataType="String">E</TransactionStatus>
        </Overview>
        <User>
          <Alias DataType="String">UK55706431GBP</Alias>
          <ClientId DataType="S32">33904</ClientId>
          <EffectiveAlias DataType="String">UK55706431GBP</EffectiveAlias>
          <EffectiveClientId DataType="S32">33904</EffectiveClientId>
          <Name DataType="String">ab123456</Name>
          <Password DataType="String">c[P5jA.6R9&gt;xOi!8</Password>
        </User>
      </EngineDoc>
      <TimeIn DataType="DateTime">1272558214306</TimeIn>
      <TimeOut DataType="DateTime">1272558214319</TimeOut>
    </EngineDocList>
    XML
  end
end

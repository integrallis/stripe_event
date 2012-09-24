require 'spec_helper'

describe StripeEvent::WebhookController do
  before do
    @base_params = {
      :type => StripeEvent::TYPE_LIST.sample,
      :use_route => :stripe_event
    }
  end

  context "with valid event data" do
    let(:event_id) { 'evt_charge_succeeded' }

    before do
      stub_event(event_id)
    end

    it "is successful" do
      post :event, @base_params.merge(:id => event_id)
      response.should be_success
    end
  end

  context "with invalid event data" do
    let(:event_id) { 'evt_invalid_id' }

    before do
      stub_event(event_id, 404)
    end

    it "denies access" do
      post :event, @base_params.merge(:id => event_id)
      response.code.should == '401'
    end
  end
  
  context "with a custom event retriever" do
    before do
      StripeEvent.event_retriever = Proc.new { |params| params }
    end
    
    it "is successful" do
      post :event, @base_params.merge(:id => '1')
      response.should be_success
    end
    
    it "fails without an event type" do
      expect {
        post :event, @base_params.merge(:id => '1', :type => nil)
      }.to raise_error(StripeEvent::InvalidEventTypeError)
    end
  end
end

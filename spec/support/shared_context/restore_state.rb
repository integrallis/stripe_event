shared_context 'restore_state' do
    let(:trust_event) { false }

    before do
      @trust_incoming_event = StripeEvent.trust_incoming_event
      StripeEvent.trust_incoming_event = trust_event
      @event_retriever = StripeEvent.event_retriever
      @notifier = StripeEvent.backend.notifier
      StripeEvent.backend.notifier = @notifier.class.new
    end

    after do
      StripeEvent.event_retriever = @event_retriever
      StripeEvent.backend.notifier = @notifier
      StripeEvent.trust_incoming_event = @trust_incoming_event
    end
end

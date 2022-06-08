use "collections"
use "promises"
use "time"

interface tag Flows[A: Any #share]
	"""
	Flow logic that will handle each state change.
	"""
	be flow(state: A, done: Continue) => None

actor NopFlows[A: Any #share] is Flows[A]
	be flow(state: A, done: Continue) =>
		done()

interface tag Continue
	be apply()

primitive NoFlowState // ideally this should be private, but llvm crashes inside ponyc...

actor AsyncFlow[A:Any val]
	"""
	Coordinated barrier between flow executions.
	"""

	var _activated: Bool // once the flow starts
	var _resumed: Bool // once upstream waiters complete
	var _fired: Bool // once we have started our flow delegate
	var _finished: Bool // once the delegate finishes
	var _flows: Flows[A]
	var _state: (A | NoFlowState)
	embed _upstream: Array[AsyncFlow[A]]
	embed _downstream: Array[AsyncFlow[A]]

	new create() =>
		_activated = false
		_resumed = false
		_fired = false
		_finished = false
		_flows = NopFlows[A]
		_state = NoFlowState
		_upstream = Array[AsyncFlow[A]]()
		_downstream = Array[AsyncFlow[A]]()

	fun tag waitn(ps: Iterator[AsyncFlow[A]]): AsyncFlow[A] =>
		"""
		Enlist a number of upstream flow waiters that must complete before this flow is released.

		This flow will only continue once all upstream flows
		have completed.
		"""
		let acopy = recover iso Array[AsyncFlow[A]] end
		for x in ps do
			acopy.push(consume x)
		end
		_waitn(recover (consume acopy).values() end)
		this

	fun tag activate(delegate: Flows[A] = NopFlows[A], state: (A | NoFlowState) = NoFlowState): AsyncFlow[A] =>
		"""
		Activate this flow and provide the asynchronous delegate to trigger.

		Once upstream flows complete, the delegate will be triggered. And, once
		the delegate completes its activity it will signal back to this async-flow
		in order to pontentially initate downstream activities.
		"""
		_activate(delegate, state)
		this

	// -- convenience

	fun tag wait(a: AsyncFlow[A]): AsyncFlow[A] => waitn([a].values())
	fun tag wait2(a: AsyncFlow[A], b: AsyncFlow[A]):AsyncFlow[A] => waitn([a;b].values())
	fun tag wait3(a: AsyncFlow[A], b: AsyncFlow[A], c: AsyncFlow[A]):AsyncFlow[A] => waitn([a;b;c].values())
	fun tag wait4(a: AsyncFlow[A], b: AsyncFlow[A], c: AsyncFlow[A], d: AsyncFlow[A]):AsyncFlow[A] => waitn([a;b;c;d].values())
	fun tag wait5(a: AsyncFlow[A], b: AsyncFlow[A], c: AsyncFlow[A], d: AsyncFlow[A], e: AsyncFlow[A]):AsyncFlow[A] => waitn([a;b;c;d;e].values())

	// -- internals

	be _waitn(ps: Iterator[AsyncFlow[A]] iso) =>
		"""
		Asynchronously add upstream flows to this flow's continuation barrier.
		"""
		if not _activated then
			let ps': Iterator[AsyncFlow[A]] ref = consume ps
			for f in ps' do
				if not _upstream.contains(f) then
					_upstream.push(f)
					f._attach(this)
				end
			end
		end

	be _activate(flows: Flows[A], state: (A | NoFlowState) ) =>
		"""
		Asynchronously activate the processing and detection of completion states.
		"""
		// record the flow engine and delegate state
		if not _activated then
			_flows = flows
			_state = state
			_activated = true
		end
		// if the activation doesn't include a flow state then mark this flow as intrinsically resumed
		match _state
		| (let s: NoFlowState) =>
			_fired = true
			_finished = true
		end
		// check if we can progress
		_check_ready()

	be _complete(completedPeer: AsyncFlow[A]) =>
		"""
		Called by a peer when the peer completes.
		"""
		// remove the peer from the pending list
		try _upstream.delete(_upstream.find(completedPeer)?)? end
		_check_ready()

	be _attach(waitingPeer: AsyncFlow[A]) =>
		"""
		Called by a peer in order subscribe for completion notifications.
		"""
		// add the peer to pending list
		if not _downstream.contains(waitingPeer) then
			_downstream.push(waitingPeer)
		end
		_check_ready()

	be _finish() =>
		"""
		Called once the flow logic is done.
		"""
		_finished = true
		_check_ready()

	fun ref _check_ready() =>
		"""
		Drive the progress based on the barrier conditions: upstream completed and flow delegate done.
		"""
		// don't change any state if we have not been activated
		if not _activated then return end
		// check if all pending peers have completed
		if _upstream.size() == 0 then
			_resumed = true
		end
		// check if we should run the flow logic
		if _resumed and (not _fired) then
			_fired = true
			_fire()
		end
		// check if we should let the downstream flows know
		if _resumed and _finished then
			_propagate_downstream()
		end

	fun ref _fire() =>
		"""
		Execute the flow logic.
		"""
		match _state
		| (let s: A) =>
			_flows.flow(s, object
				let self: AsyncFlow[A] = this
				be apply() => self._finish()
			end)
		// | we don't do anything for NoFlowState
		end

	fun ref _propagate_downstream() =>
		"""
		Signal downstream waiting flows that have completed.
		"""
		// propagate downstream
		for f in _downstream.values() do
			f._complete(this)
		end
		_downstream.clear()

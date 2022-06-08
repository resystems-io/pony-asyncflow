actor _MyFlowLogic

	be apply() =>

		let bx   = AsyncFlow[_FsFlowState].activate()
		let b1_1 = AsyncFlow[_FsFlowState].wait(bx).activate(this, _FsB1s1)
		let b1_2 = AsyncFlow[_FsFlowState].wait(bx).activate(this, _FsB1s2)
		let b1   = AsyncFlow[_FsFlowState].wait2(b1_1, b1_2)
		let b2   = AsyncFlow[_FsFlowState].wait(b1).activate(this, _FsB2)
		let b3   = AsyncFlow[_FsFlowState].wait(b2).activate(this, _FsB3)
		let b4   = AsyncFlow[_FsFlowState].wait(b3).activate(this, _FsB4)
		let b5   = AsyncFlow[_FsFlowState].wait(b4).activate(this, _FsB5)
		let b0   = AsyncFlow[_FsFlowState].wait5(b1,b2,b3,b4,b5).activate()

		let cx   = AsyncFlow[_FsFlowState].wait(b0)
		let c1   = AsyncFlow[_FsFlowState].wait(cx).activate(this, _FsC1)
		let c2   = AsyncFlow[_FsFlowState].wait(c1).activate(this, _FsC2)
		let c3   = AsyncFlow[_FsFlowState].wait(c2).activate(this, _FsC3)
		let c0   = AsyncFlow[_FsFlowState].wait3(c1,c2,c3).activate()

	be flow(state: _FsFlowState, done: Continue) =>
		match state
		| _FsB1 => None
		end
		done()

primitive _FsB1
primitive _FsB1s1
primitive _FsB1s2
primitive _FsB2
primitive _FsB3
primitive _FsB4
primitive _FsB5

primitive _FsC1
primitive _FsC2
primitive _FsC3

type _FsFlowState is (
  _FsB1
| _FsB1s1
| _FsB1s2
| _FsB2
| _FsB3
| _FsB4
| _FsB5

| _FsC1
| _FsC2
| _FsC3
)

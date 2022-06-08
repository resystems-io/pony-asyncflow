use "pony_test"

actor Main is TestList
	new create(env: Env) => PonyTest(env, this)
	new make() => None

	fun tag tests(test: PonyTest) =>
		test(_TestPingPong)

class iso _TestPingPong is UnitTest
	fun name(): String => "asyncflow/PingPong"

	fun apply(h: TestHelper) =>
		h.long_test(2_000_000)
		h.complete(true)

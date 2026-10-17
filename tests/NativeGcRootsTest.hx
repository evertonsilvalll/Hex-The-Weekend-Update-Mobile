package;

import cpp.vm.Gc;
import gc.TestBigStack;

/** Run the upstream register/stack-root regression with bounded work. */
// Exercise ARM64's setjmp capture path even on an x86_64 test host.
@:buildXml("<files id='runtime'><compilerflag value='-DHXCPP_CAPTURE_SETJMP'/></files>")
@:access(gc.TestBigStack)
class NativeGcRootsTest
{
	static function main():Void
	{
		for (pass in 0...25)
		{
			var root = new TestBigStack();
			root.run(1, 4);
			Gc.run(true);
			root.checkRec();
		}
		Sys.println("PASS: native recursive roots survive allocation pressure and forced GC");
	}
}

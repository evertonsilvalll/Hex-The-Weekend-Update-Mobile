import HEXDialougeState.HEXDialogueBox;

class HexDialogueTextTest
{
	static function main():Void
	{
		var dialogue = Type.createEmptyInstance(HEXDialogueBox);
		var cases = [
			":bf:Hello: this colon belongs to the sentence.",
			":gf:  Hello!  ",
			"Unprefixed text"
		];
		var expected = ["Hello: this colon belongs to the sentence.", "Hello!", "Unprefixed text"];
		for (i in 0...cases.length)
		{
			@:privateAccess dialogue.dialogueList = [cases[i]];
			@:privateAccess dialogue.cleanDialog();
			@:privateAccess if (dialogue.dialogueList[0] != expected[i])
				throw "Dialogue text was corrupted: " + cases[i];
		}
		Sys.println("PASS: Hex dialogue speaker prefixes, embedded colons and unprefixed text");
	}
}

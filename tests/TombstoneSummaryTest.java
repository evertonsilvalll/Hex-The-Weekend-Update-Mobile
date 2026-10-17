import com.hexmod.weekend.TombstoneSummary;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

public final class TombstoneSummaryTest {
  public static void main(String[] args) throws Exception {
    byte[] other =
        join(
            text(2, "PRIVATE OTHER THREAD"),
            message(4, frame("PRIVATE OTHER STACK")),
            number(1, 7));
    byte[] crashing =
        join(message(4, frame("lime::Renderer::render")), text(2, "SDLThread"), number(1, 42));
    byte[] signal = join(number(9, -1L), text(4, "SEGV_MAPERR"), text(2, "SIGSEGV"));
    byte[] trace =
        join(
            message(16, join(message(2, other), number(1, 7))),
            message(16, join(message(2, crashing), number(1, 42))),
            message(10, signal),
            text(14, "renderer\nfailed"),
            message(15, text(1, "Invalid texture")),
            number(22, 16384),
            number(5, 1234),
            number(6, 42));
    String result = TombstoneSummary.summarize(trace);
    contains(result, "pid: 1234, crashing tid: 42 (SDLThread)");
    contains(result, "Page size: 16384 bytes");
    contains(result, "Signal: SIGSEGV (SEGV_MAPERR), fault address: 0xffffffffffffffff");
    contains(result, "Abort: renderer failed");
    contains(result, "Cause: Invalid texture");
    contains(
        result, "#00 pc 0x1234 /data/app/liblime.so (lime::Renderer::render+17) (BuildId: abc123)");
    absent(result, "PRIVATE OTHER");

    // Every supported unknown wire type can be skipped without decoding its
    // payload. This includes memory/log bytes that are not valid UTF-8.
    byte[] unknown =
        join(
            number(50, 9), fixed(51, 1, 8), message(52, new byte[] {(byte) 0xff}), fixed(53, 5, 4));
    equal(result, TombstoneSummary.summarize(join(unknown, trace)));
    contains(TombstoneSummary.summarize(new byte[0]), "No native fault summary");
    contains(TombstoneSummary.summarize(unknown), "No native fault summary");
    contains(TombstoneSummary.summarize(message(10, number(8, 1))), "fault address: 0x0");
    contains(
        TombstoneSummary.summarize(join(number(6, 42), message(16, message(2, crashing)))),
        "SDLThread");

    byte[][] manyFrames = new byte[13][];
    for (int i = 0; i < manyFrames.length; i++) {
      manyFrames[i] = message(4, frame("frame_" + i));
    }
    String cappedFrames =
        TombstoneSummary.summarize(
            join(number(6, 42), message(16, message(2, join(number(1, 42), join(manyFrames))))));
    contains(cappedFrames, "#11 ");
    absent(cappedFrames, "#12 ");
    absent(cappedFrames, "frame_12");

    StringBuilder longText = new StringBuilder();
    for (int i = 0; i < 10000; i++) {
      longText.append('x');
    }
    for (int i = 0; i < manyFrames.length; i++) {
      manyFrames[i] = message(4, frame(longText.toString()));
    }
    String bounded =
        TombstoneSummary.summarize(
            join(number(6, 42), message(16, message(2, join(number(1, 42), join(manyFrames))))));
    check(bounded.length() <= 20000, "Summary exceeds output limit");
    contains(bounded, "[summary truncated]");

    invalid(null);
    invalid(new byte[4 * 1024 * 1024 + 1]);
    invalid(new byte[] {0});
    invalid(new byte[] {8, (byte) 0x80});
    invalid(new byte[] {8, (byte) 0x80, 0});
    invalid(
        join(
            new byte[] {8},
            new byte[] {
              (byte) 0x80,
              (byte) 0x80,
              (byte) 0x80,
              (byte) 0x80,
              (byte) 0x80,
              (byte) 0x80,
              (byte) 0x80,
              (byte) 0x80,
              (byte) 0x80,
              (byte) 0x80,
              0
            }));
    invalid(
        join(
            new byte[] {8},
            new byte[] {
              (byte) 0xff,
              (byte) 0xff,
              (byte) 0xff,
              (byte) 0xff,
              (byte) 0xff,
              (byte) 0xff,
              (byte) 0xff,
              (byte) 0xff,
              (byte) 0xff,
              2
            }));
    invalid(new byte[] {11}); // Deprecated group wire type.
    invalid(new byte[] {15});
    invalid(new byte[] {13, 0, 0, 0}); // Truncated fixed32.
    invalid(new byte[] {9, 0, 0, 0, 0, 0, 0, 0}); // Truncated fixed64.
    invalid(new byte[] {114, 3, 'a'}); // Truncated abort string.
    invalid(join(new byte[] {114}, varint(0x100000000L))); // Length beyond int range.
    invalid(number(5, 0x100000000L));
    invalid(text(5, "wrong wire"));
    invalid(number(16, 1));
    invalid(message(10, number(2, 1)));
    invalid(message(14, new byte[] {(byte) 0xc3})); // Invalid UTF-8.
    byte[] lateInvalidUtf8 = longText.toString().getBytes(StandardCharsets.UTF_8);
    lateInvalidUtf8[lateInvalidUtf8.length - 1] = (byte) 0xff;
    invalid(message(14, lateInvalidUtf8)); // Validate text beyond the retained prefix.
    invalid(
        join(
            number(6, 42),
            message(16, message(2, join(number(1, 42), message(4, new byte[] {34, 2, 'a'}))))));
    // A valid top-level frame truncated at each byte must either reject it or
    // describe just its intact prefix; it must never crash or hang.
    for (int length = 0; length < trace.length; length++) {
      byte[] prefix = new byte[length];
      System.arraycopy(trace, 0, prefix, 0, length);
      try {
        check(TombstoneSummary.summarize(prefix).length() <= 20000, "Prefix exceeded limit");
      } catch (IOException expected) {
        // Truncated protobuf fields are expected.
      }
    }
    System.out.println("TombstoneSummaryTest passed");
  }

  private static byte[] frame(String function) {
    return join(
        text(8, "abc123"),
        text(6, "/data/app/liblime.so"),
        number(5, 17),
        text(4, function),
        number(1, 0x1234));
  }

  private static byte[] text(int field, String value) {
    return message(field, value.getBytes(StandardCharsets.UTF_8));
  }

  private static byte[] message(int field, byte[] value) {
    return join(varint(((long) field << 3) | 2), varint(value.length), value);
  }

  private static byte[] number(int field, long value) {
    return join(varint((long) field << 3), varint(value));
  }

  private static byte[] fixed(int field, int wire, int length) {
    return join(varint(((long) field << 3) | wire), new byte[length]);
  }

  private static byte[] varint(long value) {
    ByteArrayOutputStream result = new ByteArrayOutputStream();
    do {
      int next = (int) (value & 0x7f);
      value >>>= 7;
      result.write(next | (value == 0 ? 0 : 0x80));
    } while (value != 0);
    return result.toByteArray();
  }

  private static byte[] join(byte[]... values) {
    ByteArrayOutputStream result = new ByteArrayOutputStream();
    for (byte[] value : values) {
      result.write(value, 0, value.length);
    }
    return result.toByteArray();
  }

  private static void invalid(byte[] input) throws Exception {
    try {
      TombstoneSummary.summarize(input);
      throw new AssertionError("Malformed trace accepted");
    } catch (IOException expected) {
      // The report launcher can handle a bounded unavailable-trace error.
    }
  }

  private static void contains(String actual, String expected) {
    check(actual.contains(expected), "Missing expected text: " + expected + " in " + actual);
  }

  private static void absent(String actual, String excluded) {
    check(!actual.contains(excluded), "Unexpected text: " + excluded);
  }

  private static void equal(String expected, String actual) {
    check(expected.equals(actual), "Unexpected summary change");
  }

  private static void check(boolean condition, String message) {
    if (!condition) {
      throw new AssertionError(message);
    }
  }
}

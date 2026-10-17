package com.hexmod.weekend;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.CharBuffer;
import java.nio.charset.CharsetDecoder;
import java.nio.charset.CoderResult;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * A deliberately narrow reader for the native crash trace supplied by ApplicationExitInfo. Schema:
 * https://android.googlesource.com/platform/system/core/+/refs/heads/main/debuggerd/proto/tombstone.proto
 * Memory dumps, logs and non-crashing thread stacks are skipped, never decoded or retained.
 */
public final class TombstoneSummary {
  private static final int MAX_INPUT = 4 * 1024 * 1024;
  private static final int MAX_OUTPUT = 20000;
  private static final int MAX_TEXT = 2048;
  private static final int MAX_FRAMES = 12;
  private static final int MAX_DEPTH = 6;

  private TombstoneSummary() {}

  public static String summarize(byte[] data) throws IOException {
    if (data == null || data.length > MAX_INPUT) {
      throw new IOException("Native trace is missing or exceeds 4 MiB");
    }
    Summary summary = new Summary();
    Reader input = new Reader(data, 0, data.length, 0);
    while (input.hasRemaining()) {
      int tag = input.tag();
      switch (tag >>> 3) {
        case 5:
          summary.pid = input.uint32(tag);
          summary.hasPid = true;
          break;
        case 6:
          summary.tid = input.uint32(tag);
          summary.hasTid = true;
          break;
        case 10:
          readSignal(input.message(tag), summary);
          break;
        case 14:
          summary.abort = input.text(tag);
          break;
        case 15:
          readCause(input.message(tag), summary);
          break;
        case 16:
          input.message(tag);
          break;
        case 22:
          summary.pageSize = input.uint32(tag);
          summary.hasPageSize = true;
          break;
        default:
          input.skip(tag);
      }
    }

    // The crashing tid can follow every map entry. A second bounded pass avoids
    // retaining all threads, their register dumps or their backtraces.
    if (summary.hasTid) {
      input = new Reader(data, 0, data.length, 0);
      while (input.hasRemaining()) {
        int tag = input.tag();
        if ((tag >>> 3) == 16) {
          Reader entry = input.message(tag);
          Reader thread = null;
          while (entry.hasRemaining()) {
            int entryTag = entry.tag();
            if ((entryTag >>> 3) == 2) {
              thread = entry.message(entryTag);
            } else {
              entry.skip(entryTag);
            }
          }
          if (thread != null && threadId(thread.copy()) == summary.tid) {
            readThread(thread, summary);
          }
        } else {
          input.skip(tag);
        }
      }
    }
    return summary.render();
  }

  private static void readSignal(Reader input, Summary summary) throws IOException {
    while (input.hasRemaining()) {
      int tag = input.tag();
      switch (tag >>> 3) {
        case 2:
          summary.signal = input.text(tag);
          break;
        case 4:
          summary.signalCode = input.text(tag);
          break;
        case 8:
          summary.hasFaultAddress = input.scalar(tag) != 0 || summary.hasFaultAddress;
          break;
        case 9:
          summary.faultAddress = input.scalar(tag);
          summary.hasFaultAddress = true;
          break;
        default:
          input.skip(tag);
      }
    }
  }

  private static void readCause(Reader input, Summary summary) throws IOException {
    while (input.hasRemaining()) {
      int tag = input.tag();
      if ((tag >>> 3) == 1) {
        String cause = input.text(tag);
        if (summary.causes.size() < 8 && !cause.isEmpty()) {
          summary.causes.add(cause);
        }
      } else {
        input.skip(tag);
      }
    }
  }

  private static long threadId(Reader input) throws IOException {
    long id = 0;
    while (input.hasRemaining()) {
      int tag = input.tag();
      if ((tag >>> 3) == 1) {
        id = input.scalar(tag);
      } else {
        input.skip(tag);
      }
    }
    return id;
  }

  private static void readThread(Reader input, Summary summary) throws IOException {
    summary.threadName = "";
    summary.frames.clear();
    while (input.hasRemaining()) {
      int tag = input.tag();
      if ((tag >>> 3) == 2) {
        summary.threadName = input.text(tag);
      } else if ((tag >>> 3) == 4) {
        Reader frame = input.message(tag);
        if (summary.frames.size() < MAX_FRAMES) {
          summary.frames.add(readFrame(frame));
        }
      } else {
        input.skip(tag);
      }
    }
  }

  private static String readFrame(Reader input) throws IOException {
    long pc = 0;
    long offset = 0;
    String function = "";
    String file = "";
    String buildId = "";
    while (input.hasRemaining()) {
      int tag = input.tag();
      switch (tag >>> 3) {
        case 1:
          pc = input.scalar(tag);
          break;
        case 4:
          function = input.text(tag);
          break;
        case 5:
          offset = input.scalar(tag);
          break;
        case 6:
          file = input.text(tag);
          break;
        case 8:
          buildId = input.text(tag);
          break;
        default:
          input.skip(tag);
      }
    }
    StringBuilder result = new StringBuilder();
    result.append("pc 0x").append(Long.toHexString(pc)).append(' ');
    result.append(file.isEmpty() ? "<unknown>" : file);
    if (!function.isEmpty()) {
      result.append(" (").append(function).append('+');
      result.append(Long.toUnsignedString(offset)).append(')');
    }
    if (!buildId.isEmpty()) {
      result.append(" (BuildId: ").append(buildId).append(')');
    }
    return result.toString();
  }

  private static final class Summary {
    long pid;
    long tid;
    long pageSize;
    long faultAddress;
    boolean hasPid;
    boolean hasTid;
    boolean hasPageSize;
    boolean hasFaultAddress;
    String signal = "";
    String signalCode = "";
    String abort = "";
    String threadName = "";
    final List<String> causes = new ArrayList<String>();
    final List<String> frames = new ArrayList<String>();

    String render() {
      StringBuilder result = new StringBuilder();
      if (hasPid || hasTid) {
        result.append("pid: ").append(pid).append(", crashing tid: ").append(tid);
        if (!threadName.isEmpty()) {
          result.append(" (").append(threadName).append(')');
        }
        result.append('\n');
      }
      if (hasPageSize) {
        result.append("Page size: ").append(pageSize).append(" bytes\n");
      }
      if (!signal.isEmpty() || !signalCode.isEmpty() || hasFaultAddress) {
        result.append("Signal: ").append(signal);
        if (!signalCode.isEmpty()) {
          result.append(" (").append(signalCode).append(')');
        }
        if (hasFaultAddress) {
          result.append(", fault address: 0x").append(Long.toHexString(faultAddress));
        }
        result.append('\n');
      }
      if (!abort.isEmpty()) {
        result.append("Abort: ").append(abort).append('\n');
      }
      for (String cause : causes) {
        result.append("Cause: ").append(cause).append('\n');
      }
      for (int i = 0; i < frames.size(); i++) {
        result.append('#');
        if (i < 10) {
          result.append('0');
        }
        result.append(i).append(' ').append(frames.get(i)).append('\n');
      }
      if (result.length() == 0) {
        return "No native fault summary fields were present.\n";
      }
      if (result.length() > MAX_OUTPUT) {
        String suffix = "\n[summary truncated]\n";
        result.setLength(MAX_OUTPUT - suffix.length());
        if (Character.isHighSurrogate(result.charAt(result.length() - 1))) {
          result.setLength(result.length() - 1);
        }
        result.append(suffix);
      }
      return result.toString();
    }
  }

  private static final class Reader {
    final byte[] data;
    final int end;
    final int depth;
    int position;

    Reader(byte[] data, int start, int end, int depth) throws IOException {
      if (depth > MAX_DEPTH) {
        throw new IOException("Native trace nesting is too deep");
      }
      this.data = data;
      this.position = start;
      this.end = end;
      this.depth = depth;
    }

    Reader copy() throws IOException {
      return new Reader(data, position, end, depth);
    }

    boolean hasRemaining() {
      return position < end;
    }

    long varint() throws IOException {
      long result = 0;
      for (int i = 0; i < 10; i++) {
        if (position >= end) {
          throw new IOException("Truncated native trace varint");
        }
        int next = data[position++] & 0xff;
        if (i == 9 && (next & 0xfe) != 0) {
          throw new IOException("Native trace varint exceeds 64 bits");
        }
        result |= (long) (next & 0x7f) << (i * 7);
        if ((next & 0x80) == 0) {
          if (i > 0 && next == 0) {
            throw new IOException("Overlong native trace varint");
          }
          return result;
        }
      }
      throw new IOException("Overlong native trace varint");
    }

    int tag() throws IOException {
      long value = varint();
      if (value <= 0 || value > 0xffffffffL || (value >>> 3) == 0) {
        throw new IOException("Invalid native trace field tag");
      }
      int wire = (int) value & 7;
      if (wire != 0 && wire != 1 && wire != 2 && wire != 5) {
        throw new IOException("Unsupported native trace wire type");
      }
      return (int) value;
    }

    void requireWire(int tag, int expected) throws IOException {
      if ((tag & 7) != expected) {
        throw new IOException("Unexpected native trace wire type");
      }
    }

    long scalar(int tag) throws IOException {
      requireWire(tag, 0);
      return varint();
    }

    long uint32(int tag) throws IOException {
      long value = scalar(tag);
      if (value < 0 || value > 0xffffffffL) {
        throw new IOException("Native trace integer exceeds 32 bits");
      }
      return value;
    }

    int length(int tag) throws IOException {
      requireWire(tag, 2);
      long size = varint();
      if (size < 0 || size > end - position) {
        throw new IOException("Invalid or truncated native trace length");
      }
      return (int) size;
    }

    Reader message(int tag) throws IOException {
      int size = length(tag);
      Reader child = new Reader(data, position, position + size, depth + 1);
      position += size;
      return child;
    }

    String text(int tag) throws IOException {
      int size = length(tag);
      ByteBuffer bytes = ByteBuffer.wrap(data, position, size);
      position += size;
      CharsetDecoder decoder = StandardCharsets.UTF_8.newDecoder();
      decoder.onMalformedInput(CodingErrorAction.REPORT);
      decoder.onUnmappableCharacter(CodingErrorAction.REPORT);
      CharBuffer chars = CharBuffer.allocate(256);
      StringBuilder result = new StringBuilder();
      while (true) {
        CoderResult state = decoder.decode(bytes, chars, true);
        chars.flip();
        while (chars.hasRemaining()) {
          char value = chars.get();
          if (result.length() < MAX_TEXT) {
            // Keep the report readable without allowing control characters
            // in native-provided names to forge report sections.
            result.append(Character.isISOControl(value) ? ' ' : value);
          }
        }
        chars.clear();
        if (state.isError()) {
          state.throwException();
        }
        if (state.isUnderflow()) {
          break;
        }
      }
      if (result.length() == MAX_TEXT && Character.isHighSurrogate(result.charAt(MAX_TEXT - 1))) {
        result.setLength(MAX_TEXT - 1);
      }
      return result.toString();
    }

    void skip(int tag) throws IOException {
      switch (tag & 7) {
        case 0:
          varint();
          return;
        case 1:
          advance(8);
          return;
        case 2:
          advance(length(tag));
          return;
        case 5:
          advance(4);
          return;
        default:
          throw new IOException("Unsupported native trace wire type");
      }
    }

    void advance(int count) throws IOException {
      if (count < 0 || count > end - position) {
        throw new IOException("Truncated native trace field");
      }
      position += count;
    }
  }
}

package com.hexmod.weekend;

import android.app.ActivityManager;
import android.app.ApplicationExitInfo;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.Process;
import android.system.Os;
import android.system.OsConstants;
import android.util.Log;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.text.DateFormat;
import java.util.Date;
import java.util.List;

/** Local, app-only startup evidence; nothing is uploaded automatically. */
public final class StartupDiagnostics {
  private static final String TAG = "HexStartup";
  private static SharedPreferences preferences;
  private static Context context;
  private static boolean handlerInstalled;

  private StartupDiagnostics() {}

  public static synchronized void initialize(Context activity) {
    context = activity.getApplicationContext();
    preferences = context.getSharedPreferences("startup-diagnostics", Context.MODE_PRIVATE);
    if (!handlerInstalled) {
      final Thread.UncaughtExceptionHandler previous = Thread.getDefaultUncaughtExceptionHandler();
      Thread.setDefaultUncaughtExceptionHandler(
          new Thread.UncaughtExceptionHandler() {
            @Override
            public void uncaughtException(Thread thread, Throwable error) {
              try {
                recordError("Java: " + Log.getStackTraceString(error));
              } finally {
                if (previous != null) previous.uncaughtException(thread, error);
                else {
                  Process.killProcess(Process.myPid());
                  System.exit(10);
                }
              }
            }
          });
      handlerInstalled = true;
    }
  }

  public static synchronized void beginAttempt() {
    if (preferences == null) return;
    preferences
        .edit()
        .putLong("attemptAt", System.currentTimeMillis())
        .putString("stage", "Android: iniciando bibliotecas nativas")
        .putString("attemptVersion", version())
        .remove("error")
        .remove("graphics")
        .commit();
  }

  public static synchronized void mark(String stage) {
    Log.i(TAG, stage);
    if (preferences != null) preferences.edit().putString("stage", limit(stage, 500)).commit();
  }

  public static synchronized void recordError(String error) {
    Log.e(TAG, error);
    if (preferences != null) {
      // Keep the loader's original failure if SDL later raises another exception.
      String previous = preferences.getString("error", "");
      String combined = previous.isEmpty() ? error : previous + "\n\nErro seguinte:\n" + error;
      preferences.edit().putString("error", limit(combined, 12000)).commit();
    }
  }

  /** Called on the render thread after Lime creates its OpenGL context. */
  public static synchronized void recordGraphics(String graphics) {
    if (preferences != null)
      preferences.edit().putString("graphics", limit(graphics, 1500)).commit();
  }

  public static String report() {
    StringBuilder text = new StringBuilder("HEX — DIAGNÓSTICO DE INICIALIZAÇÃO\n");
    text.append("APK: ").append(version()).append('\n');
    text.append("Aparelho: ")
        .append(Build.MANUFACTURER)
        .append(' ')
        .append(Build.MODEL)
        .append('\n');
    text.append("Android: ")
        .append(Build.VERSION.RELEASE)
        .append(" (API ")
        .append(Build.VERSION.SDK_INT)
        .append(")\n");
    text.append("ABIs: ")
        .append(android.text.TextUtils.join(", ", Build.SUPPORTED_ABIS))
        .append('\n');
    if (Build.VERSION.SDK_INT >= 23) {
      text.append("Processo: ").append(Process.is64Bit() ? "64 bits" : "32 bits").append('\n');
    }
    try {
      text.append("Página de memória: ")
          .append(Os.sysconf(OsConstants._SC_PAGESIZE))
          .append(" bytes\n");
      ActivityManager manager =
          (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
      ActivityManager.MemoryInfo memory = new ActivityManager.MemoryInfo();
      manager.getMemoryInfo(memory);
      text.append("RAM total/livre: ")
          .append(memory.totalMem / 1048576)
          .append('/')
          .append(memory.availMem / 1048576)
          .append(" MiB\n");
    } catch (Exception error) {
      text.append("Memória: indisponível\n");
    }
    if (preferences != null) {
      long at = preferences.getLong("attemptAt", 0);
      if (at != 0) {
        text.append("Tentativa: ")
            .append(DateFormat.getDateTimeInstance().format(new Date(at)))
            .append('\n');
        text.append("Versão da tentativa: ")
            .append(preferences.getString("attemptVersion", "?"))
            .append('\n');
      }
      text.append("Última etapa: ")
          .append(preferences.getString("stage", "jogo ainda não iniciado nesta versão"))
          .append('\n');
      text.append(preferences.getString("graphics", "GPU: ainda não consultada pelo jogo"))
          .append('\n');
      String error = preferences.getString("error", "");
      if (!error.isEmpty()) text.append("\nErro registrado:\n").append(error).append('\n');
    }
    if (Build.VERSION.SDK_INT >= 30) appendExitInfo(text);
    else text.append("\nHistórico de encerramento exige Android 11+.\n");
    return limit(text.toString(), 28000);
  }

  private static void appendExitInfo(StringBuilder text) {
    text.append("\nÚltimo processo encerrado pelo Android (pode ser de uma versão anterior):\n");
    try {
      ActivityManager manager =
          (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
      List<ApplicationExitInfo> exits =
          manager.getHistoricalProcessExitReasons(context.getPackageName(), 0, 1);
      if (exits.isEmpty()) {
        text.append("Nenhum registro disponível.\n");
        return;
      }
      ApplicationExitInfo exit = exits.get(0);
      text.append("Data: ")
          .append(DateFormat.getDateTimeInstance().format(new Date(exit.getTimestamp())))
          .append('\n');
      text.append("Motivo: ")
          .append(reason(exit.getReason()))
          .append(" (")
          .append(exit.getReason())
          .append(")\n");
      text.append("Status: ")
          .append(exit.getStatus())
          .append("; PID: ")
          .append(exit.getPid())
          .append('\n');
      if (exit.getDescription() != null)
        text.append("Descrição: ").append(limit(exit.getDescription(), 2000)).append('\n');
      if (exit.getReason() == ApplicationExitInfo.REASON_CRASH_NATIVE
          && Build.VERSION.SDK_INT >= 31) {
        try (InputStream input = exit.getTraceInputStream()) {
          if (input == null) text.append("Pilha nativa: não disponibilizada pelo Android.\n");
          else text.append(TombstoneSummary.summarize(readBounded(input)));
        }
      }
    } catch (Exception error) {
      text.append("Detalhes indisponíveis: ").append(limit(error.toString(), 500)).append('\n');
    }
  }

  private static byte[] readBounded(InputStream input) throws java.io.IOException {
    ByteArrayOutputStream output = new ByteArrayOutputStream();
    byte[] buffer = new byte[8192];
    int count;
    while ((count = input.read(buffer)) != -1) {
      if (output.size() + count > 4 * 1024 * 1024)
        throw new java.io.IOException("Registro nativo excede 4 MiB");
      output.write(buffer, 0, count);
    }
    return output.toByteArray();
  }

  private static String reason(int value) {
    switch (value) {
      case ApplicationExitInfo.REASON_CRASH_NATIVE:
        return "falha nativa";
      case ApplicationExitInfo.REASON_CRASH:
        return "exceção Java";
      case ApplicationExitInfo.REASON_LOW_MEMORY:
        return "falta de memória";
      case ApplicationExitInfo.REASON_ANR:
        return "aplicativo sem resposta";
      case ApplicationExitInfo.REASON_INITIALIZATION_FAILURE:
        return "falha de inicialização";
      case ApplicationExitInfo.REASON_EXIT_SELF:
        return "saída do aplicativo";
      case ApplicationExitInfo.REASON_SIGNALED:
        return "encerrado por sinal";
      case ApplicationExitInfo.REASON_USER_REQUESTED:
        return "encerramento solicitado pelo usuário/sistema";
      default:
        return "outro";
    }
  }

  private static String version() {
    try {
      android.content.pm.PackageInfo info =
          context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
      return info.versionName + " (" + info.versionCode + ")";
    } catch (Exception error) {
      return "desconhecida";
    }
  }

  private static String limit(String value, int max) {
    return value == null ? "" : value.substring(0, Math.min(value.length(), max));
  }
}

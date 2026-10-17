package ::APP_PACKAGE::;

import android.util.Log;

/** Capture loader failures before SDL turns them into a dialog. */
public class MainActivity extends org.haxe.lime.GameActivity {
  @Override
  public void loadLibraries() {
    StartupDiagnostics.initialize(this);
    StartupDiagnostics.mark("Android: carregando bibliotecas");
    try {
      super.loadLibraries();
      StartupDiagnostics.mark("Android: bibliotecas carregadas; aguardando Haxe");
    } catch (UnsatisfiedLinkError error) {
      StartupDiagnostics.recordError(Log.getStackTraceString(error));
      throw error;
    } catch (RuntimeException error) {
      StartupDiagnostics.recordError(Log.getStackTraceString(error));
      throw error;
    }
  }
}

package com.hexmod.weekend;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

/** Java-only launcher: remains readable when the native game cannot start. */
public final class StartupActivity extends Activity {
  private TextView reportView;
  private String report = "Carregando diagnóstico…";
  private int generation;

  @Override
  public void onCreate(Bundle state) {
    super.onCreate(state);
    StartupDiagnostics.initialize(this);
    LinearLayout content = new LinearLayout(this);
    content.setOrientation(LinearLayout.VERTICAL);
    int pad = (int) (16 * getResources().getDisplayMetrics().density);
    content.setPadding(pad, pad, pad, pad);
    TextView explanation = new TextView(this);
    explanation.setText(
        "Versão de diagnóstico do Hex. Toque em Iniciar jogo. Se fechar, abra o app novamente e copie o relatório para enviar na conversa.");
    content.addView(explanation);
    LinearLayout buttons = new LinearLayout(this);
    Button start = new Button(this);
    start.setText("Iniciar jogo");
    start.setOnClickListener(
        new View.OnClickListener() {
          @Override
          public void onClick(View view) {
            StartupDiagnostics.beginAttempt();
            Intent intent = new Intent();
            intent.setClassName(StartupActivity.this, getPackageName() + ".MainActivity");
            try {
              startActivity(intent);
            } catch (RuntimeException error) {
              StartupDiagnostics.recordError(error.toString());
              refresh();
            }
          }
        });
    buttons.addView(start, new LinearLayout.LayoutParams(0, -2, 1));
    Button copy = new Button(this);
    copy.setText("Copiar relatório");
    copy.setOnClickListener(
        new View.OnClickListener() {
          @Override
          public void onClick(View view) {
            ClipboardManager clipboard = (ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
            clipboard.setPrimaryClip(ClipData.newPlainText("Hex diagnóstico", report));
            Toast.makeText(
                    StartupActivity.this, "Relatório copiado. Cole na conversa.", Toast.LENGTH_LONG)
                .show();
          }
        });
    buttons.addView(copy, new LinearLayout.LayoutParams(0, -2, 1));
    content.addView(buttons);
    reportView = new TextView(this);
    reportView.setTextIsSelectable(true);
    reportView.setTextSize(13);
    ScrollView scroll = new ScrollView(this);
    scroll.addView(reportView);
    content.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1));
    setContentView(content);
  }

  @Override
  public void onResume() {
    super.onResume();
    refresh();
  }

  @Override
  public void onDestroy() {
    generation++;
    super.onDestroy();
  }

  private void refresh() {
    final int request = ++generation;
    reportView.setText("Carregando diagnóstico…");
    new Thread(
            new Runnable() {
              @Override
              public void run() {
                String next;
                try {
                  next = StartupDiagnostics.report();
                } catch (RuntimeException error) {
                  next = "Não foi possível ler o diagnóstico: " + error;
                }
                final String ready = next;
                runOnUiThread(
                    new Runnable() {
                      @Override
                      public void run() {
                        if (!isFinishing() && generation == request) {
                          report = ready;
                          reportView.setText(ready);
                        }
                      }
                    });
              }
            },
            "HexStartupReport")
        .start();
  }
}

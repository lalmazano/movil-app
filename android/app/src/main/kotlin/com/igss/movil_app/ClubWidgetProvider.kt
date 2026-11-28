package com.igss.movil_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar
import java.util.TimeZone

/**
 * Widget de la pantalla de inicio: aniversario, próxima película, próximo plan
 * y próxima fecha importante.
 *
 * Los textos los guarda la app con `home_widget` (ver `widget_inicio.dart`).
 * Los días del aniversario y de la fecha importante se recalculan aquí para que avancen cada día aunque
 * la app no se abra.
 */
class ClubWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    for (id in appWidgetIds) {
      val vistas = RemoteViews(context.packageName, R.layout.widget_club)

      mostrar(vistas, R.id.widget_aniversario, textoAniversario(widgetData))
      // Antes de que la app guarde algo se deja el texto de "Abre la app".
      if (widgetData.contains("listo")) {
        mostrar(vistas, R.id.widget_pelicula, widgetData.getString("pelicula", null))
        mostrar(vistas, R.id.widget_plan, widgetData.getString("plan", null))
        mostrar(vistas, R.id.widget_fecha, textoFecha(widgetData))
      }

      // Al tocar el widget se abre la app.
      vistas.setOnClickPendingIntent(
          R.id.widget_raiz,
          HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
      )
      appWidgetManager.updateAppWidget(id, vistas)
    }
  }

  private fun mostrar(vistas: RemoteViews, id: Int, texto: String?) {
    if (texto.isNullOrEmpty()) {
      vistas.setViewVisibility(id, View.GONE)
    } else {
      vistas.setTextViewText(id, texto)
      vistas.setViewVisibility(id, View.VISIBLE)
    }
  }

  /** "💛 467 días juntos" con la fecha de hoy; si algo falla, el texto de la app. */
  private fun textoAniversario(datos: SharedPreferences): String? {
    val respaldo = datos.getString("aniversario", null)
    val fecha = datos.getString("aniversario_fecha", null) ?: return respaldo
    val partes = fecha.split("-").mapNotNull { it.toIntOrNull() }
    if (partes.size != 3) return respaldo

    val hoy = Calendar.getInstance()
    val dias =
        diaEpoca(hoy.get(Calendar.YEAR), hoy.get(Calendar.MONTH), hoy.get(Calendar.DAY_OF_MONTH)) -
            diaEpoca(partes[0], partes[1] - 1, partes[2])
    return when {
      dias == 0L -> "¡Hoy empieza todo! 🫘"
      dias == 1L -> "💛 1 día juntos"
      dias > 1L -> "💛 $dias días juntos"
      dias == -1L -> "💛 Falta 1 día"
      else -> "💛 Faltan ${-dias} días"
    }
  }

  /**
   * "📆 Cumpleaños de Ana · Faltan 12 días" con la fecha de hoy. Si la fecha
   * ya pasó se oculta (la app guarda la siguiente al abrirse); con 60 días o
   * más usa el texto de la app ("En 3 meses").
   */
  private fun textoFecha(datos: SharedPreferences): String? {
    val respaldo = datos.getString("fecha", null) ?: return null
    val titulo = datos.getString("fecha_titulo", null) ?: return respaldo
    val dias = diasHasta(datos.getString("fecha_dia", null)) ?: return respaldo
    val cuenta =
        when {
          dias < 0L -> return null
          dias == 0L -> "¡Hoy! 🎉"
          dias == 1L -> "Mañana"
          dias < 60L -> "Faltan $dias días"
          else -> return respaldo
        }
    val extra = datos.getString("fecha_extra", null)
    return if (extra.isNullOrEmpty()) "$titulo · $cuenta" else "$titulo · $cuenta · $extra"
  }

  /** Días de hoy a una fecha "aaaa-mm-dd" (negativo si ya pasó), o null. */
  private fun diasHasta(fecha: String?): Long? {
    val partes = fecha?.split("-")?.mapNotNull { it.toIntOrNull() } ?: return null
    if (partes.size != 3) return null
    val hoy = Calendar.getInstance()
    return diaEpoca(partes[0], partes[1] - 1, partes[2]) -
        diaEpoca(hoy.get(Calendar.YEAR), hoy.get(Calendar.MONTH), hoy.get(Calendar.DAY_OF_MONTH))
  }

  /** Días desde 1970 de una fecha de calendario (en UTC, sin horario de verano). */
  private fun diaEpoca(anio: Int, mes: Int, dia: Int): Long {
    val c = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
    c.clear()
    c.set(anio, mes, dia)
    return c.timeInMillis / MILIS_POR_DIA
  }

  private companion object {
    const val MILIS_POR_DIA = 24L * 60 * 60 * 1000
  }
}

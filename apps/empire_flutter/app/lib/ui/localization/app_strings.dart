import 'package:flutter/widgets.dart';

class AppStrings {
  AppStrings._();

  static const Map<String, Map<String, String>> _localized =
      <String, Map<String, String>>{
    'en': <String, String>{
      'auth.welcomeBack': 'Welcome back',
      'auth.welcomeToScholesa': 'Welcome to Scholesa',
      'auth.signInSubtitle': 'Sign in to continue your learning journey',
      'auth.email': 'Email',
      'auth.password': 'Password',
      'auth.emailHint': 'you@example.com',
      'auth.passwordHint': '••••••••',
      'auth.forgotPassword': 'Forgot password?',
      'auth.signIn': 'Sign In',
      'auth.orContinueWith': 'or continue with',
      'auth.google': 'Google',
      'auth.microsoft': 'Microsoft',
      'auth.provisioningNote':
          'Accounts are provisioned by your site or HQ admin.',
      'auth.resetPassword': 'Reset Password',
      'auth.resetPasswordHelp':
          'Enter your email address and we\'ll send you a link to reset your password.',
      'auth.cancel': 'Cancel',
      'auth.sendResetLink': 'Send Reset Link',
      'auth.resetEmailSent': 'Password reset email sent. Check your inbox.',
      'auth.validation.enterEmail': 'Please enter your email',
      'auth.validation.validEmail': 'Please enter a valid email',
      'auth.validation.enterPassword': 'Please enter your password',
      'auth.validation.passwordLength':
          'Password must be at least 6 characters',
      'auth.error.userNotFound': 'No account found with this email',
      'auth.error.wrongPassword': 'Incorrect password',
      'auth.error.invalidCredential': 'Invalid email or password',
      'auth.error.emailInUse': 'An account already exists with this email',
      'auth.error.weakPassword': 'Password is too weak',
      'auth.error.invalidEmail': 'Invalid email address',
      'auth.error.userDisabled': 'This account has been disabled',
      'auth.error.tooManyRequests': 'Too many attempts. Please try again later',
      'auth.error.networkFailed':
          'Network error. Check your connection and try again',
      'auth.error.operationNotAllowed': 'Email/password sign-in is not enabled',
      'auth.error.invalidApiKey':
          'Authentication is misconfigured. Contact support',
      'auth.error.appNotAuthorized':
          'This app is not authorized for Firebase Auth',
      'auth.error.popupClosed': 'Sign-in popup was closed before completion',
      'auth.error.popupBlocked': 'Sign-in popup was blocked by your browser',
      'auth.error.googleFailed': 'Failed to sign in with Google',
      'auth.error.microsoftFailed': 'Failed to sign in with Microsoft',
      'auth.error.profileLoadFailed': 'Failed to load user profile',
      'auth.error.generic': 'Authentication failed',
      'auth.error.unexpected': 'An unexpected error occurred',
      'auth.error.resetFailed': 'Failed to send reset email',
      'app.title': 'Scholesa',
      'app.bootstrapFailed': 'Failed to start Scholesa',
      'app.retry': 'Retry',
      'assistant.tooltip': 'AI Assistant',
      'assistant.title': 'AI Assistant',
      'assistant.close': 'Close',
      'assistant.loading': 'Loading assistant…',
      'ai.error.unreachable':
          'Unable to reach AI Coach right now. Try again in a moment.',
      'ai.voice.transcriptionUnavailable':
          'Voice transcription unavailable. Please type your question.',
      'ai.voice.microphonePermissionRequired':
          'Microphone permission is required for voice input.',
      'ai.voice.playbackStopped': 'Playback stopped',
      'ai.voice.stopListening': 'Stop listening',
      'ai.voice.useInput': 'Use voice input',
      'ai.voice.disableOutput': 'Disable voice output',
      'ai.voice.enableOutput': 'Enable voice output',
      'ai.voice.speaking': 'Speaking…',
      'ai.voice.tapInterrupt': 'Tap to interrupt',
      'ai.voice.outputUnavailable':
          'Voice output is unavailable. Check device volume and audio permissions.',
      'ai.voice.outputUnavailableWeb':
          'Voice output is blocked in the browser. Use HTTPS, allow autoplay/audio, and try again.',
      'ai.clearGoals.title': 'Clear current goals?',
      'ai.clearGoals.body':
          'This removes the in-session coaching goals memory for this assistant conversation.',
      'ai.clear': 'Clear',
      'ai.currentGoals': 'Current goals',
      'ai.clearGoals.cta': 'Clear goals',
      'ai.empty.title': 'AI Coach',
      'ai.empty.subtitle':
          'Select a mode and ask for help. I\'ll guide your thinking — not give answers.',
      'ai.banner.verification':
          'Verification active — show your understanding first.',
      'ai.chat.verificationRequired': 'Verification required',
      'ai.chat.helpful': 'Helpful?',
      'ai.feedback.thanks': 'Thanks for the feedback!',
      'ai.feedback.noted': 'Noted — we\'ll improve.',
      'ai.enrich.retryPrompt':
          'Let\'s try that again. What part feels most confusing right now?',
      'ai.enrich.hintFollowup': 'What have you tried so far?',
      'ai.enrich.verifyFollowup': 'Can you show the evidence for your answer?',
      'ai.enrich.explainFollowup':
          'How would you explain that in your own words?',
      'ai.enrich.debugFollowup':
          'What changed right before the issue started?',
      'ai.mode.hintPlaceholder': 'Ask for a hint...',
      'ai.mode.verifyPlaceholder': 'Describe your approach to verify...',
      'ai.mode.explainPlaceholder': 'What would you like explained?',
      'ai.mode.debugPlaceholder': 'Describe the issue you\'re seeing...',
      'ai.mode.hintLabel': 'Hint',
      'ai.mode.verifyLabel': 'Verify',
      'ai.mode.explainLabel': 'Explain',
      'ai.mode.debugLabel': 'Debug',
      'ai.directive.hint':
          'Give one focused hint first, then ask a short guiding question.',
      'ai.directive.verify':
          'Verify reasoning with evidence checks and ask for one concrete proof step.',
      'ai.directive.explain':
          'Explain in simple steps and relate to one practical example.',
      'ai.directive.debug':
          'Diagnose likely causes, suggest one small test, and ask what changed recently.',
      'ai.role.learner':
          'Speak directly to a learner using supportive, age-appropriate coaching language.',
      'ai.role.parent':
          'Coach with parent-friendly phrasing that supports the learner without giving answers.',
      'ai.role.staff':
          'Respond as an instructional co-pilot with concise pedagogical suggestions.',
    },
    'es': <String, String>{
      'auth.welcomeBack': 'Bienvenido de nuevo',
      'auth.welcomeToScholesa': 'Bienvenido a Scholesa',
      'auth.signInSubtitle':
          'Inicia sesión para continuar tu viaje de aprendizaje',
      'auth.email': 'Correo electrónico',
      'auth.password': 'Contraseña',
      'auth.emailHint': 'tu@ejemplo.com',
      'auth.passwordHint': '••••••••',
      'auth.forgotPassword': '¿Olvidaste tu contraseña?',
      'auth.signIn': 'Iniciar sesión',
      'auth.orContinueWith': 'o continúa con',
      'auth.google': 'Google',
      'auth.microsoft': 'Microsoft',
      'auth.provisioningNote':
          'Las cuentas son aprovisionadas por el administrador del sitio o HQ.',
      'auth.resetPassword': 'Restablecer contraseña',
      'auth.resetPasswordHelp':
          'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
      'auth.cancel': 'Cancelar',
      'auth.sendResetLink': 'Enviar enlace',
      'auth.resetEmailSent':
          'Correo de restablecimiento enviado. Revisa tu bandeja de entrada.',
      'auth.validation.enterEmail': 'Por favor ingresa tu correo electrónico',
      'auth.validation.validEmail': 'Por favor ingresa un correo válido',
      'auth.validation.enterPassword': 'Por favor ingresa tu contraseña',
      'auth.validation.passwordLength':
          'La contraseña debe tener al menos 6 caracteres',
      'auth.error.userNotFound': 'No se encontró una cuenta con este correo',
      'auth.error.wrongPassword': 'Contraseña incorrecta',
      'auth.error.invalidCredential': 'Correo o contraseña inválidos',
      'auth.error.emailInUse': 'Ya existe una cuenta con este correo',
      'auth.error.weakPassword': 'La contraseña es demasiado débil',
      'auth.error.invalidEmail': 'Correo electrónico inválido',
      'auth.error.userDisabled': 'Esta cuenta ha sido deshabilitada',
      'auth.error.tooManyRequests': 'Demasiados intentos. Inténtalo más tarde',
      'auth.error.networkFailed':
          'Error de red. Verifica tu conexión e inténtalo de nuevo',
      'auth.error.operationNotAllowed':
          'El inicio de sesión con correo/contraseña no está habilitado',
      'auth.error.invalidApiKey':
          'La autenticación está mal configurada. Contacta soporte',
      'auth.error.appNotAuthorized':
          'Esta app no está autorizada para Firebase Auth',
      'auth.error.popupClosed':
          'La ventana emergente de inicio de sesión se cerró antes de completarse',
      'auth.error.popupBlocked':
          'La ventana emergente fue bloqueada por el navegador',
      'auth.error.googleFailed': 'No se pudo iniciar sesión con Google',
      'auth.error.microsoftFailed': 'No se pudo iniciar sesión con Microsoft',
      'auth.error.profileLoadFailed': 'No se pudo cargar el perfil de usuario',
      'auth.error.generic': 'Falló la autenticación',
      'auth.error.unexpected': 'Ocurrió un error inesperado',
      'auth.error.resetFailed':
          'No se pudo enviar el correo de restablecimiento',
      'app.title': 'Scholesa',
      'app.bootstrapFailed': 'No se pudo iniciar Scholesa',
      'app.retry': 'Reintentar',
      'assistant.tooltip': 'Asistente de IA',
      'assistant.title': 'Asistente de IA',
      'assistant.close': 'Cerrar',
      'assistant.loading': 'Cargando asistente…',
      'ai.error.unreachable':
          'No se puede conectar con el Coach de IA ahora. Inténtalo de nuevo en un momento.',
      'ai.voice.transcriptionUnavailable':
          'La transcripción de voz no está disponible. Escribe tu pregunta.',
      'ai.voice.microphonePermissionRequired':
          'Se requiere permiso de micrófono para la entrada por voz.',
      'ai.voice.playbackStopped': 'Reproducción detenida',
      'ai.voice.stopListening': 'Detener escucha',
      'ai.voice.useInput': 'Usar entrada por voz',
      'ai.voice.disableOutput': 'Desactivar salida de voz',
      'ai.voice.enableOutput': 'Activar salida de voz',
      'ai.voice.speaking': 'Hablando…',
      'ai.voice.tapInterrupt': 'Toca para interrumpir',
      'ai.voice.outputUnavailable':
          'La salida de voz no está disponible. Verifica el volumen y los permisos de audio del dispositivo.',
      'ai.voice.outputUnavailableWeb':
          'La salida de voz está bloqueada en el navegador. Usa HTTPS, permite reproducción automática/audio y vuelve a intentar.',
      'ai.clearGoals.title': '¿Borrar metas actuales?',
      'ai.clearGoals.body':
          'Esto elimina la memoria de metas de coaching en sesión para esta conversación del asistente.',
      'ai.clear': 'Borrar',
      'ai.currentGoals': 'Metas actuales',
      'ai.clearGoals.cta': 'Borrar metas',
      'ai.empty.title': 'Coach de IA',
      'ai.empty.subtitle':
          'Selecciona un modo y pide ayuda. Guiaré tu pensamiento, sin dar respuestas.',
      'ai.banner.verification':
          'Verificación activa — muestra primero tu comprensión.',
      'ai.chat.verificationRequired': 'Verificación requerida',
      'ai.chat.helpful': '¿Útil?',
      'ai.feedback.thanks': '¡Gracias por tu comentario!',
      'ai.feedback.noted': 'Anotado — mejoraremos.',
      'ai.enrich.retryPrompt':
          'Intentémoslo de nuevo. ¿Qué parte te resulta más confusa ahora?',
      'ai.enrich.hintFollowup': '¿Qué has intentado hasta ahora?',
      'ai.enrich.verifyFollowup':
          '¿Puedes mostrar la evidencia de tu respuesta?',
      'ai.enrich.explainFollowup':
          '¿Cómo lo explicarías con tus propias palabras?',
      'ai.enrich.debugFollowup':
          '¿Qué cambió justo antes de que comenzara el problema?',
      'ai.mode.hintPlaceholder': 'Pide una pista...',
      'ai.mode.verifyPlaceholder': 'Describe tu enfoque para verificar...',
      'ai.mode.explainPlaceholder': '¿Qué te gustaría que se explicara?',
      'ai.mode.debugPlaceholder': 'Describe el problema que estás viendo...',
      'ai.mode.hintLabel': 'Pista',
      'ai.mode.verifyLabel': 'Verificar',
      'ai.mode.explainLabel': 'Explicar',
      'ai.mode.debugLabel': 'Depurar',
      'ai.directive.hint':
          'Da primero una pista enfocada y luego haz una pregunta guía corta.',
      'ai.directive.verify':
          'Verifica el razonamiento con evidencia y pide un paso de prueba concreto.',
      'ai.directive.explain':
          'Explica en pasos simples y relaciónalo con un ejemplo práctico.',
      'ai.directive.debug':
          'Diagnostica causas probables, sugiere una prueba pequeña y pregunta qué cambió recientemente.',
      'ai.role.learner':
          'Habla directamente a un estudiante con lenguaje de apoyo y apropiado para su edad.',
      'ai.role.parent':
          'Guía con lenguaje apto para familias que apoye al estudiante sin dar respuestas.',
      'ai.role.staff':
          'Responde como copiloto instruccional con sugerencias pedagógicas concisas.',
    },
  };

  static String of(BuildContext context, String key) {
    final String localeCode =
        Localizations.localeOf(context).languageCode.toLowerCase();
    final Map<String, String> selected =
        _localized[localeCode] ?? _localized['en']!;
    return selected[key] ?? _localized['en']![key] ?? key;
  }
}

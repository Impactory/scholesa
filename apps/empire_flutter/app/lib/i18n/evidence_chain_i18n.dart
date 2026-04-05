import 'package:flutter/material.dart';

import '../ui/localization/inline_locale_text.dart';

/// Evidence chain internationalization strings
///
/// Centralized i18n keys for all evidence chain surfaces:
/// checkpoint submission, reflection journal, proof of learning,
/// rubric & capability, observation & evidence, peer feedback,
/// and portfolio & growth.
///
/// **Usage**:
/// ```dart
/// import 'package:scholesa/i18n/evidence_chain_i18n.dart';
///
/// final label = EvidenceChainI18n.text(context, 'Submit Checkpoint');
/// ```
class EvidenceChainI18n {
  EvidenceChainI18n._();

  static const Map<String, String> _zhCn = <String, String>{
    // -- Checkpoint Submission --
    'Checkpoint': '检查点',
    'Submit Checkpoint': '提交检查点',
    'Checkpoint History': '检查点历史',
    'Question': '问题',
    'Your Answer': '你的回答',
    'Explain It Back': '解释回讲',
    'Explain your reasoning': '解释你的推理',
    'Score': '分数',
    'Correct': '正确',
    'Incorrect': '错误',
    'Passed': '已通过',
    'Failed': '未通过',
    'Submit': '提交',
    'Try Again': '再试一次',
    'Well done!': '做得好！',

    // -- Reflection Journal --
    'Reflection Journal': '反思日志',
    'New Reflection': '新反思',
    'How did it go?': '进展如何？',
    'What did you learn?': '你学到了什么？',
    'Confidence': '自信程度',
    'Engagement': '参与度',
    'Low': '低',
    'Medium': '中',
    'High': '高',
    'Save Reflection': '保存反思',
    'Educator Notes': '教育者笔记',
    'Reflections': '反思记录',

    // -- Proof of Learning --
    'Proof of Learning': '学习证明',
    'Assemble Proof': '组装证明',
    'Explain-It-Back': '解释回讲',
    'Oral Check': '口头检查',
    'Mini-Rebuild': '小型重建',
    'Verification Status': '验证状态',
    'Verified': '已验证',
    'Partial': '部分完成',
    'Missing': '缺失',
    'Add Evidence': '添加证据',
    'Submit for Verification': '提交验证',
    'Proof Bundle': '证明包',
    'Version': '版本',
    'Educator Verified': '教育者已验证',
    'Pending Verification': '等待验证',

    // -- Rubric & Capability --
    'Rubric': '量规',
    'Apply Rubric': '应用量规',
    'Rubric Builder': '量规构建器',
    'Capability Framework': '能力框架',
    'Capability': '能力',
    'Capabilities': '能力项',
    'Progression': '进阶',
    'Emerging': '起步',
    'Developing': '发展中',
    'Proficient': '熟练',
    'Advanced': '进阶',
    'Mastery Level': '掌握水平',
    'Growth Event': '成长事件',
    'Micro-Skill': '微技能',
    'Pillar': '支柱',

    // -- Observation & Evidence --
    'Observation': '观察',
    'Capture Observation': '记录观察',
    'Evidence Record': '证据记录',
    'Evidence Type': '证据类型',
    'Artifact': '作品',
    'Reflection': '反思',
    'Observer Notes': '观察者笔记',
    'Engagement Level': '参与程度',
    'Participation': '参与度',
    'Save Observation': '保存观察',
    'Verify Evidence': '验证证据',

    // -- Peer Feedback --
    'Peer Feedback': '同伴反馈',
    'Give Feedback': '给予反馈',
    'Strengths': '优点',
    'Suggestions': '建议',
    'Rating': '评分',
    'Submit Feedback': '提交反馈',
    'Feedback History': '反馈历史',
    'From': '来自',

    // -- Portfolio & Growth --
    'Growth Timeline': '成长时间线',
    'Capability Growth': '能力成长',
    'Portfolio Curation': '作品集策展',
    'Link Evidence': '关联证据',
    'Showcase': '展示',
    'Weekly Goal': '每周目标',
    'Goal Progress': '目标进度',
    'Set Goal': '设定目标',
    'View Growth': '查看成长',
    'Evidence Linked': '已关联证据',
  };

  static const Map<String, String> _zhTw = <String, String>{
    // -- Checkpoint Submission --
    'Checkpoint': '檢查點',
    'Submit Checkpoint': '提交檢查點',
    'Checkpoint History': '檢查點歷史',
    'Question': '問題',
    'Your Answer': '你的回答',
    'Explain It Back': '解釋回講',
    'Explain your reasoning': '解釋你的推理',
    'Score': '分數',
    'Correct': '正確',
    'Incorrect': '錯誤',
    'Passed': '已通過',
    'Failed': '未通過',
    'Submit': '提交',
    'Try Again': '再試一次',
    'Well done!': '做得好！',

    // -- Reflection Journal --
    'Reflection Journal': '反思日誌',
    'New Reflection': '新反思',
    'How did it go?': '進展如何？',
    'What did you learn?': '你學到了什麼？',
    'Confidence': '自信程度',
    'Engagement': '參與度',
    'Low': '低',
    'Medium': '中',
    'High': '高',
    'Save Reflection': '儲存反思',
    'Educator Notes': '教育者筆記',
    'Reflections': '反思紀錄',

    // -- Proof of Learning --
    'Proof of Learning': '學習證明',
    'Assemble Proof': '組裝證明',
    'Explain-It-Back': '解釋回講',
    'Oral Check': '口頭檢查',
    'Mini-Rebuild': '小型重建',
    'Verification Status': '驗證狀態',
    'Verified': '已驗證',
    'Partial': '部分完成',
    'Missing': '缺失',
    'Add Evidence': '新增證據',
    'Submit for Verification': '提交驗證',
    'Proof Bundle': '證明包',
    'Version': '版本',
    'Educator Verified': '教育者已驗證',
    'Pending Verification': '等待驗證',

    // -- Rubric & Capability --
    'Rubric': '量規',
    'Apply Rubric': '套用量規',
    'Rubric Builder': '量規建構器',
    'Capability Framework': '能力框架',
    'Capability': '能力',
    'Capabilities': '能力項',
    'Progression': '進階',
    'Emerging': '起步',
    'Developing': '發展中',
    'Proficient': '熟練',
    'Advanced': '進階',
    'Mastery Level': '掌握水準',
    'Growth Event': '成長事件',
    'Micro-Skill': '微技能',
    'Pillar': '支柱',

    // -- Observation & Evidence --
    'Observation': '觀察',
    'Capture Observation': '記錄觀察',
    'Evidence Record': '證據紀錄',
    'Evidence Type': '證據類型',
    'Artifact': '作品',
    'Reflection': '反思',
    'Observer Notes': '觀察者筆記',
    'Engagement Level': '參與程度',
    'Participation': '參與度',
    'Save Observation': '儲存觀察',
    'Verify Evidence': '驗證證據',

    // -- Peer Feedback --
    'Peer Feedback': '同儕回饋',
    'Give Feedback': '給予回饋',
    'Strengths': '優點',
    'Suggestions': '建議',
    'Rating': '評分',
    'Submit Feedback': '提交回饋',
    'Feedback History': '回饋歷史',
    'From': '來自',

    // -- Portfolio & Growth --
    'Growth Timeline': '成長時間線',
    'Capability Growth': '能力成長',
    'Portfolio Curation': '作品集策展',
    'Link Evidence': '連結證據',
    'Showcase': '展示',
    'Weekly Goal': '每週目標',
    'Goal Progress': '目標進度',
    'Set Goal': '設定目標',
    'View Growth': '查看成長',
    'Evidence Linked': '已連結證據',
  };

  static const Map<String, String> _es = <String, String>{
    // -- Checkpoint Submission --
    'Checkpoint': 'Punto de control',
    'Submit Checkpoint': 'Enviar punto de control',
    'Checkpoint History': 'Historial de puntos de control',
    'Question': 'Pregunta',
    'Your Answer': 'Tu respuesta',
    'Explain It Back': 'Explica con tus palabras',
    'Explain your reasoning': 'Explica tu razonamiento',
    'Score': 'Puntuación',
    'Correct': 'Correcto',
    'Incorrect': 'Incorrecto',
    'Passed': 'Aprobado',
    'Failed': 'No aprobado',
    'Submit': 'Enviar',
    'Try Again': 'Intentar de nuevo',
    'Well done!': '¡Bien hecho!',

    // -- Reflection Journal --
    'Reflection Journal': 'Diario de reflexión',
    'New Reflection': 'Nueva reflexión',
    'How did it go?': '¿Cómo te fue?',
    'What did you learn?': '¿Qué aprendiste?',
    'Confidence': 'Confianza',
    'Engagement': 'Participación',
    'Low': 'Bajo',
    'Medium': 'Medio',
    'High': 'Alto',
    'Save Reflection': 'Guardar reflexión',
    'Educator Notes': 'Notas del educador',
    'Reflections': 'Reflexiones',

    // -- Proof of Learning --
    'Proof of Learning': 'Prueba de aprendizaje',
    'Assemble Proof': 'Armar prueba',
    'Explain-It-Back': 'Explicación propia',
    'Oral Check': 'Verificación oral',
    'Mini-Rebuild': 'Mini reconstrucción',
    'Verification Status': 'Estado de verificación',
    'Verified': 'Verificado',
    'Partial': 'Parcial',
    'Missing': 'Faltante',
    'Add Evidence': 'Agregar evidencia',
    'Submit for Verification': 'Enviar para verificación',
    'Proof Bundle': 'Paquete de pruebas',
    'Version': 'Versión',
    'Educator Verified': 'Verificado por educador',
    'Pending Verification': 'Verificación pendiente',

    // -- Rubric & Capability --
    'Rubric': 'Rúbrica',
    'Apply Rubric': 'Aplicar rúbrica',
    'Rubric Builder': 'Constructor de rúbricas',
    'Capability Framework': 'Marco de capacidades',
    'Capability': 'Capacidad',
    'Capabilities': 'Capacidades',
    'Progression': 'Progresión',
    'Emerging': 'Inicial',
    'Developing': 'En desarrollo',
    'Proficient': 'Competente',
    'Advanced': 'Avanzado',
    'Mastery Level': 'Nivel de dominio',
    'Growth Event': 'Evento de crecimiento',
    'Micro-Skill': 'Micro-habilidad',
    'Pillar': 'Pilar',

    // -- Observation & Evidence --
    'Observation': 'Observación',
    'Capture Observation': 'Registrar observación',
    'Evidence Record': 'Registro de evidencia',
    'Evidence Type': 'Tipo de evidencia',
    'Artifact': 'Artefacto',
    'Reflection': 'Reflexión',
    'Observer Notes': 'Notas del observador',
    'Engagement Level': 'Nivel de participación',
    'Participation': 'Participación',
    'Save Observation': 'Guardar observación',
    'Verify Evidence': 'Verificar evidencia',

    // -- Peer Feedback --
    'Peer Feedback': 'Retroalimentación entre pares',
    'Give Feedback': 'Dar retroalimentación',
    'Strengths': 'Fortalezas',
    'Suggestions': 'Sugerencias',
    'Rating': 'Calificación',
    'Submit Feedback': 'Enviar retroalimentación',
    'Feedback History': 'Historial de retroalimentación',
    'From': 'De',

    // -- Portfolio & Growth --
    'Growth Timeline': 'Línea de tiempo de crecimiento',
    'Capability Growth': 'Crecimiento de capacidades',
    'Portfolio Curation': 'Curación del portafolio',
    'Link Evidence': 'Vincular evidencia',
    'Showcase': 'Exhibición',
    'Weekly Goal': 'Meta semanal',
    'Goal Progress': 'Progreso de la meta',
    'Set Goal': 'Establecer meta',
    'View Growth': 'Ver crecimiento',
    'Evidence Linked': 'Evidencia vinculada',
  };

  static const Map<String, String> _th = <String, String>{
    // -- Checkpoint Submission --
    'Checkpoint': 'จุดตรวจ',
    'Submit Checkpoint': 'ส่งจุดตรวจ',
    'Checkpoint History': 'ประวัติจุดตรวจ',
    'Question': 'คำถาม',
    'Your Answer': 'คำตอบของคุณ',
    'Explain It Back': 'อธิบายย้อนกลับ',
    'Explain your reasoning': 'อธิบายเหตุผลของคุณ',
    'Score': 'คะแนน',
    'Correct': 'ถูกต้อง',
    'Incorrect': 'ไม่ถูกต้อง',
    'Passed': 'ผ่าน',
    'Failed': 'ไม่ผ่าน',
    'Submit': 'ส่ง',
    'Try Again': 'ลองอีกครั้ง',
    'Well done!': 'ทำได้ดีมาก!',

    // -- Reflection Journal --
    'Reflection Journal': 'บันทึกการสะท้อนคิด',
    'New Reflection': 'สะท้อนคิดใหม่',
    'How did it go?': 'เป็นอย่างไรบ้าง?',
    'What did you learn?': 'คุณได้เรียนรู้อะไร?',
    'Confidence': 'ความมั่นใจ',
    'Engagement': 'การมีส่วนร่วม',
    'Low': 'ต่ำ',
    'Medium': 'ปานกลาง',
    'High': 'สูง',
    'Save Reflection': 'บันทึกการสะท้อนคิด',
    'Educator Notes': 'บันทึกของผู้สอน',
    'Reflections': 'บันทึกสะท้อนคิด',

    // -- Proof of Learning --
    'Proof of Learning': 'หลักฐานการเรียนรู้',
    'Assemble Proof': 'รวบรวมหลักฐาน',
    'Explain-It-Back': 'อธิบายย้อนกลับ',
    'Oral Check': 'ตรวจสอบปากเปล่า',
    'Mini-Rebuild': 'สร้างใหม่ขนาดเล็ก',
    'Verification Status': 'สถานะการตรวจสอบ',
    'Verified': 'ตรวจสอบแล้ว',
    'Partial': 'บางส่วน',
    'Missing': 'ขาดหาย',
    'Add Evidence': 'เพิ่มหลักฐาน',
    'Submit for Verification': 'ส่งเพื่อตรวจสอบ',
    'Proof Bundle': 'ชุดหลักฐาน',
    'Version': 'เวอร์ชัน',
    'Educator Verified': 'ผู้สอนตรวจสอบแล้ว',
    'Pending Verification': 'รอการตรวจสอบ',

    // -- Rubric & Capability --
    'Rubric': 'เกณฑ์การประเมิน',
    'Apply Rubric': 'ใช้เกณฑ์การประเมิน',
    'Rubric Builder': 'ตัวสร้างเกณฑ์การประเมิน',
    'Capability Framework': 'กรอบสมรรถนะ',
    'Capability': 'สมรรถนะ',
    'Capabilities': 'สมรรถนะ',
    'Progression': 'ความก้าวหน้า',
    'Emerging': 'เริ่มต้น',
    'Developing': 'กำลังพัฒนา',
    'Proficient': 'ชำนาญ',
    'Advanced': 'ขั้นสูง',
    'Mastery Level': 'ระดับความเชี่ยวชาญ',
    'Growth Event': 'เหตุการณ์การเติบโต',
    'Micro-Skill': 'ทักษะย่อย',
    'Pillar': 'เสาหลัก',

    // -- Observation & Evidence --
    'Observation': 'การสังเกต',
    'Capture Observation': 'บันทึกการสังเกต',
    'Evidence Record': 'บันทึกหลักฐาน',
    'Evidence Type': 'ประเภทหลักฐาน',
    'Artifact': 'ผลงาน',
    'Reflection': 'การสะท้อนคิด',
    'Observer Notes': 'บันทึกของผู้สังเกต',
    'Engagement Level': 'ระดับการมีส่วนร่วม',
    'Participation': 'การมีส่วนร่วม',
    'Save Observation': 'บันทึกการสังเกต',
    'Verify Evidence': 'ตรวจสอบหลักฐาน',

    // -- Peer Feedback --
    'Peer Feedback': 'ข้อเสนอแนะจากเพื่อน',
    'Give Feedback': 'ให้ข้อเสนอแนะ',
    'Strengths': 'จุดแข็ง',
    'Suggestions': 'ข้อเสนอแนะ',
    'Rating': 'การให้คะแนน',
    'Submit Feedback': 'ส่งข้อเสนอแนะ',
    'Feedback History': 'ประวัติข้อเสนอแนะ',
    'From': 'จาก',

    // -- Portfolio & Growth --
    'Growth Timeline': 'ไทม์ไลน์การเติบโต',
    'Capability Growth': 'การเติบโตด้านสมรรถนะ',
    'Portfolio Curation': 'การจัดการแฟ้มผลงาน',
    'Link Evidence': 'เชื่อมโยงหลักฐาน',
    'Showcase': 'จัดแสดง',
    'Weekly Goal': 'เป้าหมายรายสัปดาห์',
    'Goal Progress': 'ความคืบหน้าเป้าหมาย',
    'Set Goal': 'ตั้งเป้าหมาย',
    'View Growth': 'ดูการเติบโต',
    'Evidence Linked': 'หลักฐานที่เชื่อมโยง',
  };

  /// Get an evidence chain string in the user's locale.
  /// English keys are used as-is for the en locale.
  static String text(BuildContext context, String input) {
    return InlineLocaleText.of(
      context,
      input,
      zhCn: _zhCn,
      zhTw: _zhTw,
      es: _es,
      th: _th,
    );
  }
}

import fs from 'node:fs';
import path from 'node:path';

const repoRoot = path.resolve(__dirname, '../..');

function readRepoFile(...relativePath: string[]): string {
  return fs.readFileSync(path.join(repoRoot, ...relativePath), 'utf8');
}

describe('AI help wording availability', () => {
  it('keeps the web AI popup wired to friendly aiCoach locale keys at visible UI touchpoints', () => {
    const popupSource = readRepoFile('src', 'components', 'sdt', 'AICoachPopup.tsx');

    expect(popupSource).toContain("title={t('aiCoach.tooltip')}");
    expect(popupSource).toContain("aria-label={t('aiCoach.openAria')}");
    expect(popupSource).toContain("<h3 className=\"font-semibold\">{t('aiCoach.title')}</h3>");
    expect(popupSource).toContain("aria-label={t('aiCoach.minimizeAria')}");
    expect(popupSource).toContain("{t('aiCoach.teacherGuidance')}");
    expect(popupSource).toContain("{t('aiCoach.voiceRequirements')}");
    expect(popupSource).toContain("{t('aiCoach.responseLabel')}");
    expect(popupSource).toContain("{t('aiCoach.footerTip')}");
    expect(popupSource).toContain('MiloOS is being careful here because it could not understand the voice request clearly enough yet.');
    expect(popupSource).toContain('MiloOS answered with a simple local hint because it could not confirm the voice request clearly. Treat this as a prompt to think, not a verified reading of what you meant.');
    expect(popupSource).toContain('MiloOS used the model to write the reply, but it still could not confirm the voice request clearly.');
    expect(popupSource).toContain('Confidence in that reading:');
    expect(popupSource).toContain('MiloOS used both a quick local check and model support to understand this voice turn.');
    expect(popupSource).toContain('MiloOS used model support to understand this voice turn.');
    expect(popupSource).toContain('MiloOS could not understand this voice turn reliably, so it switched to a safer fallback reply.');
    expect(popupSource).toContain('MiloOS could not clearly capture what you said. Please try again and speak a little more clearly.');
    expect(popupSource).toContain('MiloOS could not clearly capture what you said. Please try again.');
    expect(popupSource).not.toContain('voice understanding stayed heuristic');
    expect(popupSource).not.toContain('local heuristic support');
    expect(popupSource).not.toContain('model-backed understanding');
    expect(popupSource).not.toContain('intent understanding remained heuristic');
    expect(popupSource).not.toContain('blended heuristic and model understanding');
    expect(popupSource).not.toContain('model-derived understanding');
    expect(popupSource).not.toContain('reliable voice inference turn');
    expect(popupSource).not.toContain('reliable voice transcript');
  });

  it('keeps service-unavailable help copy aligned across web guardrails and voice backends', () => {
    const guardrailSource = readRepoFile('src', 'lib', 'ai', 'multilingualGuardrails.ts');
    const voiceSystemSource = readRepoFile('functions', 'src', 'voiceSystem.ts');
    const functionIndexSource = readRepoFile('functions', 'src', 'index.ts');

    const requiredSnippets = [
      'AI help is not ready to give a reliable answer right now. Share your work so far, or ask your educator to review the next step with you.',
      'AI 帮助现在还不能提供足够可靠的回答。你可以先分享你目前的思路，或者请老师陪你一起看下一步。',
      'AI 幫助現在還不能提供足夠可靠的回答。你可以先分享你目前的思路，或者請老師陪你一起看下一步。',
      'ความช่วยเหลือจาก AI ยังไม่พร้อมให้คำตอบที่เชื่อถือได้ในตอนนี้ ลองเล่าสิ่งที่ทำมาถึงตอนนี้ หรือให้ครูช่วยดูขั้นต่อไปกับคุณ',
    ];

    for (const source of [guardrailSource, voiceSystemSource, functionIndexSource]) {
      for (const requiredSnippet of requiredSnippets) {
        expect(source).toContain(requiredSnippet);
      }

      expect(source).not.toContain('The AI coach is not ready to give a reliable answer right now.');
      expect(source).not.toContain('AI 教练现在还不能提供足够可靠的回答。');
      expect(source).not.toContain('AI 教練現在還不能提供足夠可靠的回答。');
      expect(source).not.toContain('โค้ช AI ยังไม่พร้อมให้คำตอบที่เชื่อถือได้ในตอนนี้');
    }
  });

  it('keeps shared web locale catalogs on friendly AI help and learning signal wording', () => {
    const localeExpectations = [
      {
        relativePath: ['packages', 'i18n', 'locales', 'en.json'],
        required: [
          '"title": "AI Help"',
          '"tooltip": "Ask for help"',
          '"responseLabel": "AI Help:"',
          '"voiceRequirements": "Sign in, enable microphone access, and finish voice setup before using voice help."',
          '"sessionLoopTitle": "Session Learning Signals"',
          '"improvementScore": "Growth Trend"',
          '"mvlStatus": "Understanding Check"',
          '"latestSignal": "Latest Update"',
        ],
        forbidden: ['AI Coach', 'BOS/MIA Session Loop', 'Mastery Validation', 'Improvement Score', 'Latest Signal', 'Voice API'],
      },
      {
        relativePath: ['packages', 'i18n', 'locales', 'zh-CN.json'],
        required: [
          '"title": "AI 帮助"',
          '"responseLabel": "AI 帮助："',
          '"voiceRequirements": "请先登录、启用麦克风权限，并完成语音设置后再使用语音帮助。"',
          '"sessionLoopTitle": "课堂学习信号"',
          '"improvementScore": "成长趋势"',
          '"mvlStatus": "理解检查"',
          '"latestSignal": "最新更新"',
        ],
        forbidden: ['AI Coach', 'BOS/MIA Session Loop', 'Mastery Validation', 'Improvement Score', 'Latest Signal', 'Voice API'],
      },
      {
        relativePath: ['packages', 'i18n', 'locales', 'zh-TW.json'],
        required: [
          '"title": "AI 幫助"',
          '"responseLabel": "AI 幫助："',
          '"voiceRequirements": "請先登入、啟用麥克風權限，並完成語音設定後再使用語音幫助。"',
          '"sessionLoopTitle": "課堂學習訊號"',
          '"improvementScore": "成長趨勢"',
          '"mvlStatus": "理解檢查"',
          '"latestSignal": "最新更新"',
        ],
        forbidden: ['AI Coach', 'BOS/MIA Session Loop', 'Mastery Validation', 'Improvement Score', 'Latest Signal', 'Voice API'],
      },
      {
        relativePath: ['packages', 'i18n', 'locales', 'es.json'],
        required: [
          '"openAria": "Abrir ayuda de IA"',
          '"responseLabel": "Ayuda de IA:"',
          '"voiceRequirements": "Inicia sesión, habilita el micrófono y termina la configuración de voz antes de usar la ayuda por voz."',
          '"sessionLoopTitle": "Señales de aprendizaje de la sesión"',
          '"improvementScore": "Tendencia de crecimiento"',
          '"mvlStatus": "Comprobación de comprensión"',
          '"latestSignal": "Actualización más reciente"',
        ],
        forbidden: ['AI Coach', 'BOS/MIA Session Loop', 'Mastery Validation', 'Improvement Score', 'Latest Signal', 'Voice API'],
      },
      {
        relativePath: ['packages', 'i18n', 'locales', 'th.json'],
        required: [
          '"title": "AI Help"',
          '"tooltip": "ขอความช่วยเหลือ"',
          '"responseLabel": "AI Help:"',
          '"voiceRequirements": "ลงชื่อเข้าใช้ เปิดสิทธิ์ไมโครโฟน และตั้งค่าเสียงให้เสร็จก่อนใช้ความช่วยเหลือด้วยเสียง"',
          '"sessionLoopTitle": "สัญญาณการเรียนรู้ของคาบนี้"',
          '"improvementScore": "แนวโน้มการเติบโต"',
          '"mvlStatus": "การตรวจสอบความเข้าใจ"',
          '"latestSignal": "อัปเดตล่าสุด"',
        ],
        forbidden: ['AI Coach', 'BOS/MIA Session Loop', 'Mastery Validation', 'Improvement Score', 'Latest Signal', 'Voice API'],
      },
      {
        relativePath: ['locales', 'en.json'],
        required: ['"voiceRequirements": "Sign in, enable microphone access, and finish voice setup before using voice help."'],
        forbidden: ['AI Coach', 'Voice API'],
      },
      {
        relativePath: ['locales', 'zh-CN.json'],
        required: ['"voiceRequirements": "请先登录、启用麦克风权限，并完成语音设置后再使用语音帮助。"'],
        forbidden: ['AI Coach', 'Voice API'],
      },
      {
        relativePath: ['locales', 'zh-TW.json'],
        required: ['"voiceRequirements": "請先登入、啟用麥克風權限，並完成語音設定後再使用語音幫助。"'],
        forbidden: ['AI Coach', 'Voice API'],
      },
      {
        relativePath: ['locales', 'th.json'],
        required: ['"voiceRequirements": "ลงชื่อเข้าใช้ เปิดสิทธิ์ไมโครโฟน และตั้งค่าเสียงให้เสร็จก่อนใช้ความช่วยเหลือด้วยเสียง"'],
        forbidden: ['AI Coach', 'Voice API'],
      },
    ];

    for (const expectation of localeExpectations) {
      const source = readRepoFile(...expectation.relativePath);

      for (const requiredSnippet of expectation.required) {
        expect(source).toContain(requiredSnippet);
      }

      for (const forbiddenSnippet of expectation.forbidden) {
        expect(source).not.toContain(forbiddenSnippet);
      }
    }
  });
});
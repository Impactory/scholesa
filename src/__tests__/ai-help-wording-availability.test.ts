import fs from 'node:fs';
import path from 'node:path';

const repoRoot = path.resolve(__dirname, '../..');

function readRepoFile(...relativePath: string[]): string {
  return fs.readFileSync(path.join(repoRoot, ...relativePath), 'utf8');
}

describe('AI help wording availability', () => {
  it('keeps the web AI popup wired to friendly aiCoach locale keys at visible UI touchpoints', () => {
    const popupSource = readRepoFile('src', 'components', 'sdt', 'AICoachPopup.tsx');
    const screenSource = readRepoFile('src', 'components', 'sdt', 'AICoachScreen.tsx');
    const learnerDashboardSource = readRepoFile('src', 'features', 'dashboards', 'learner', 'components', 'LearnerDashboard.tsx');
    const pricingPlansSource = readRepoFile('src', 'components', 'stripe', 'PricingPlans.tsx');

    expect(popupSource).toContain("title={t('aiCoach.tooltip')}");
    expect(popupSource).toContain("aria-label={t('aiCoach.openAria')}");
    expect(popupSource).toContain("<h3 className=\"font-semibold\">{t('aiCoach.title')}</h3>");
    expect(popupSource).toContain("aria-label={t('aiCoach.minimizeAria')}");
    expect(popupSource).toContain("{t('aiCoach.teacherGuidance')}");
    expect(popupSource).toContain("{t('aiCoach.voiceRequirements')}");
    expect(popupSource).toContain("{t('aiCoach.footerTip')}");
    expect(popupSource).toContain('AI Help answered out loud.');
    expect(popupSource).toContain('Replay spoken response');
    expect(popupSource).toContain('AI Help prepared a spoken response, but this device could not play it out loud. Turn on audio and try Replay.');
    expect(popupSource).toContain('Open AI Help from the learner workspace to record explain-back for this session.');
    expect(popupSource).toContain('Explain-back recorded for this AI help session.');
    expect(popupSource).toContain('Unable to record explain-back right now. Open the learner AI Help screen or try again later.');
    expect(popupSource).toContain('AI Help is being careful here because it could not understand the voice request clearly enough yet.');
    expect(popupSource).toContain('AI Help answered with a simple local hint because it could not confirm the voice request clearly. Treat this as a prompt to think, not a verified reading of what you meant.');
    expect(popupSource).toContain('AI Help used the model to write the reply, but it still could not confirm the voice request clearly.');
    expect(popupSource).toContain('Confidence in that reading:');
    expect(popupSource).toContain('AI Help used both a quick local check and model support to understand this voice turn.');
    expect(popupSource).toContain('AI Help used model support to understand this voice turn.');
    expect(popupSource).toContain('AI Help could not understand this voice turn reliably, so it switched to a safer fallback reply.');
    expect(popupSource).toContain('AI Help could not clearly capture what you said. Please try again and speak a little more clearly.');
    expect(popupSource).toContain('AI Help could not clearly capture what you said. Please try again.');
    expect(popupSource).not.toContain('{response.answer}');
    expect(popupSource).not.toContain('voice understanding stayed heuristic');
    expect(popupSource).not.toContain('local heuristic support');
    expect(popupSource).not.toContain('model-backed understanding');
    expect(popupSource).not.toContain('intent understanding remained heuristic');
    expect(popupSource).not.toContain('blended heuristic and model understanding');
    expect(popupSource).not.toContain('model-derived understanding');
    expect(popupSource).not.toContain('reliable voice inference turn');
    expect(popupSource).not.toContain('reliable voice transcript');

    expect(screenSource).toContain('AI Help');
    expect(screenSource).toContain('Ask AI Help');
    expect(screenSource).toContain('AI Help answered out loud.');
    expect(screenSource).toContain('Replay spoken response');
    expect(screenSource).toContain('AI Help prepared a spoken response, but this browser could not play it out loud. Turn on audio and try Replay.');
    expect(screenSource).toContain('AI Help is here to help you think, not to do the work for you.');
    expect(screenSource).not.toContain('{response.message}');
    expect(screenSource).not.toContain('Ask AI Coach');
    expect(screenSource).not.toContain('AI Coach says:');
    expect(screenSource).not.toContain('The AI Coach is here to help you think');

    expect(learnerDashboardSource).toContain('AI Help');
    expect(learnerDashboardSource).toContain('AI help appears here when a real support response is available.');
    expect(learnerDashboardSource).toContain('No live help response is attached to this dashboard card yet.');
    expect(learnerDashboardSource).not.toContain('AI Coach');
    expect(learnerDashboardSource).not.toContain('AI coach guidance appears here');

    expect(pricingPlansSource).toContain('AI help and guidance');
    expect(pricingPlansSource).not.toContain('AI coaching support');
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
          '"title": "ความช่วยเหลือจาก AI"',
          '"tooltip": "ขอความช่วยเหลือ"',
          '"responseLabel": "ความช่วยเหลือจาก AI:"',
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
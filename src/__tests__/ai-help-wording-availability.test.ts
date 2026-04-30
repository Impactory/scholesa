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
    const dockSource = readRepoFile('src', 'components', 'sdt', 'GlobalAIAssistantDock.tsx');
    const spokenResponseHookSource = readRepoFile('src', 'hooks', 'useSpokenResponse.ts');
    const voiceServiceSource = readRepoFile('src', 'lib', 'voice', 'voiceService.ts');
    const voiceErrorSource = readRepoFile('src', 'lib', 'voice', 'userFacingVoiceErrors.ts');
    const learnerDashboardSource = readRepoFile('src', 'features', 'dashboards', 'learner', 'components', 'LearnerDashboard.tsx');
    const pricingPlansSource = readRepoFile('src', 'components', 'stripe', 'PricingPlans.tsx');

    expect(popupSource).toContain("title={t('aiCoach.tooltip')}");
    expect(popupSource).toContain("aria-label={t('aiCoach.openAria')}");
    expect(popupSource).toContain("<h3 className=\"font-semibold\">{t('aiCoach.title')}</h3>");
    expect(popupSource).toContain("aria-label={t('aiCoach.minimizeAria')}");
    expect(popupSource).toContain("{t('aiCoach.teacherGuidance')}");
    expect(popupSource).toContain("{t('aiCoach.voiceRequirements')}");
    expect(popupSource).toContain("{t('aiCoach.footerTip')}");
    expect(popupSource).toContain('useSpokenResponse');
    expect(popupSource).toContain("{t('aiCoach.spokenResponseHeadline')}");
    expect(popupSource).toContain("{t('aiCoach.replaySpokenResponse')}");
    const enLocaleSource = readRepoFile('packages', 'i18n', 'locales', 'en.json');
    expect(enLocaleSource).toContain('"spokenResponseHeadline": "MiloOS answered out loud."');
    expect(enLocaleSource).toContain('"replaySpokenResponse": "Replay spoken response"');
    expect(popupSource).toContain('Open MiloOS from the learner workspace to record explain-back for this session.');
    expect(popupSource).toContain('Explain-back recorded for this MiloOS session.');
    expect(popupSource).toContain('Unable to record explain-back right now. Open the learner MiloOS screen or try again later.');
    expect(popupSource).toContain('MiloOS response transcript');
    expect(popupSource).toContain('Audio was not available, so read the MiloOS answer below before explaining it back.');
    expect(popupSource).toContain('playResponseWithTranscriptStatus');
    expect(popupSource).toContain('MiloOS is being careful here because it could not understand the voice request clearly enough yet.');
    expect(popupSource).toContain('MiloOS answered with a simple local hint because it could not confirm the voice request clearly. Treat this as a prompt to think, not a verified reading of what you meant.');
    expect(popupSource).toContain('MiloOS used the model to write the reply, but it still could not confirm the voice request clearly.');
    expect(popupSource).toContain('Confidence in that reading:');
    expect(popupSource).toContain('MiloOS used both a quick local check and model support to understand this voice turn.');
    expect(popupSource).toContain('MiloOS used model support to understand this voice turn.');
    expect(popupSource).toContain('MiloOS could not understand this voice turn reliably, so it switched to a safer fallback reply.');
    expect(popupSource).toContain('MiloOS could not clearly capture what you said. Please try again and speak a little more clearly.');
    expect(popupSource).toContain('getUserFacingVoiceTranscriptionError');
    expect(popupSource).toContain('Voice capture is unavailable. Please sign in and complete voice setup to use MiloOS by voice.');
    expect(popupSource).toContain('Sign in to use MiloOS by voice.');
    expect(popupSource).toContain('Voice help is not available right now. Complete voice setup and try again.');
    expect(popupSource).toContain('ai_help_voice_model');
    expect(popupSource).toContain('ai_help_voice_guardrail');
    expect(popupSource).toContain('ai_help_voice_local_support');
    expect(popupSource).toContain("console.error('Voice playback failed in MiloOS popup:'");
    expect(popupSource).toContain("console.error('Voice transcription failed in MiloOS popup.'");
    expect(popupSource).toContain("console.error('MiloOS error:'");
    expect(popupSource).toContain("console.error('MiloOS popup explain-back error:'");
    expect(popupSource).not.toContain('{response.answer}');
    expect(popupSource).not.toContain("t('aiCoach.poweredBy'");
    expect(popupSource).not.toContain('Voice playback failed in AI coach popup:');
    expect(popupSource).not.toContain('Voice transcription failed in AI coach popup.');
    expect(popupSource).not.toContain('AI Coach error:');
    expect(popupSource).not.toContain('AI coach popup explain-back error:');
    expect(popupSource).not.toContain('BOS AI Coach');
    expect(popupSource).not.toContain('miloos_voice_model');
    expect(popupSource).not.toContain('miloos_voice_guardrail');
    expect(popupSource).not.toContain('miloos_voice_local_support');
    expect(popupSource).not.toContain('Voice API');
    expect(popupSource).not.toContain('voice understanding stayed heuristic');
    expect(popupSource).not.toContain('local heuristic support');
    expect(popupSource).not.toContain('model-backed understanding');
    expect(popupSource).not.toContain('intent understanding remained heuristic');
    expect(popupSource).not.toContain('blended heuristic and model understanding');
    expect(popupSource).not.toContain('model-derived understanding');
    expect(popupSource).not.toContain('reliable voice inference turn');
    expect(popupSource).not.toContain('reliable voice transcript');

    expect(screenSource).toContain('MiloOS');
    expect(screenSource).toContain('Ask MiloOS');
    expect(screenSource).toContain('MiloOS answered out loud.');
    expect(screenSource).toContain('MiloOS response transcript');
    expect(screenSource).toContain('Audio was not available, so read the MiloOS answer below before explaining it back.');
    expect(screenSource).toContain('Replay spoken response');
    expect(screenSource).toContain('useVoiceTranscription');
    expect(screenSource).toContain('useSpokenResponse');
    expect(screenSource).toContain('Speak your question');
    expect(screenSource).toContain('Speak now');
    expect(screenSource).toContain('MiloOS is here to help you think, not to do the work for you.');
    expect(screenSource).toContain('Voice capture is unavailable. Please sign in and complete voice setup to use MiloOS by voice.');
    expect(screenSource).toContain('getUserFacingVoiceTranscriptionError');
    expect(screenSource).toContain("console.error('MiloOS error:'");
    expect(screenSource).toContain("console.error('Microphone capture unavailable for MiloOS screen:'");
    expect(screenSource).toContain("console.error('Voice transcription failed in MiloOS screen:'");
    expect(screenSource).toContain("console.error('MiloOS explain-back error:'");
    expect(screenSource).not.toContain('Ask AI Coach');
    expect(screenSource).not.toContain('AI Coach says:');
    expect(screenSource).not.toContain('The AI Coach is here to help you think');
    expect(screenSource).not.toContain('AI Coach error:');
    expect(screenSource).not.toContain('Microphone capture unavailable for AI coach screen:');
    expect(screenSource).not.toContain('Voice transcription failed in AI coach screen:');
    expect(screenSource).not.toContain('AI Coach explain-back error:');
    expect(screenSource).not.toContain('ensure voice setup is available');
    expect(screenSource).not.toContain('voiceError instanceof Error && voiceError.message');

    expect(dockSource).toContain('<AICoachPopup');
    expect(dockSource).toContain('resolveActiveSiteId');
    expect(dockSource).toContain("t('common.userLabel')");
    expect(dockSource).toContain("console.error('Failed to load linked roster for AI assistant dock.'");
    expect(dockSource).not.toContain('AI Coach');
    expect(dockSource).not.toContain('MiloOS');
    expect(dockSource).not.toContain('Voice API');

    expect(voiceErrorSource).toContain('MiloOS could not clearly capture what you said. Please try again.');
    expect(voiceErrorSource).toContain('Sign in to use MiloOS by voice.');
    expect(voiceErrorSource).toContain('MiloOS voice is not available right now. Complete voice setup and try again.');
    expect(voiceErrorSource).toContain('MiloOS voice took too long to respond. Please try again.');

    expect(learnerDashboardSource).toContain('MiloOS');
    expect(learnerDashboardSource).toContain('No learning signals yet. Start a session to see your MiloOS support snapshot.');
    expect(learnerDashboardSource).toContain('Learning signals from your latest session');
    expect(learnerDashboardSource).not.toContain('AI Coach');
    expect(learnerDashboardSource).not.toContain('AI coach guidance appears here');
    expect(learnerDashboardSource).not.toContain('MiloOS appears here when a real support response is available.');

    expect(pricingPlansSource).toContain('MiloOS help and guidance');
    expect(pricingPlansSource).not.toContain('AI coaching support');

    expect(spokenResponseHookSource).toContain('MiloOS answered out loud. Replay the spoken response if you need to hear it again.');
    expect(spokenResponseHookSource).toContain('MiloOS answered out loud using this device audio. Replay the spoken response if you need to hear it again.');
    expect(spokenResponseHookSource).toContain('MiloOS prepared a spoken response, but this device could not play it out loud. Turn on audio and try Replay.');

    expect(voiceServiceSource).toContain('Voice help took too long to respond. Please try again.');
    expect(voiceServiceSource).toContain('Voice help is unavailable right now. Complete voice setup and try again.');
    expect(voiceServiceSource).not.toContain('Voice API request timed out.');
    expect(voiceServiceSource).not.toContain('Voice API base URL is not configured.');
  });

  it('keeps service-unavailable help copy aligned across web guardrails and voice backends', () => {
    const guardrailSource = readRepoFile('src', 'lib', 'ai', 'multilingualGuardrails.ts');
    const voiceSystemSource = readRepoFile('functions', 'src', 'voiceSystem.ts');
    const functionIndexSource = readRepoFile('functions', 'src', 'index.ts');

    const requiredSnippets = [
      'MiloOS is not ready to give a reliable answer right now. Share your work so far, or ask your educator to review the next step with you.',
      'MiloOS 现在还不能提供足够可靠的回答。你可以先分享你目前的思路，或者请老师陪你一起看下一步。',
      'MiloOS 現在還不能提供足夠可靠的回答。你可以先分享你目前的思路，或者請老師陪你一起看下一步。',
      'MiloOS ยังไม่พร้อมให้คำตอบที่เชื่อถือได้ในตอนนี้ ลองเล่าสิ่งที่ทำมาถึงตอนนี้ หรือให้ครูช่วยดูขั้นต่อไปกับคุณ',
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
          '"title": "MiloOS"',
          '"tooltip": "Ask for help"',
          '"responseLabel": "MiloOS:"',
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
          '"title": "MiloOS"',
          '"responseLabel": "MiloOS:"',
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
          '"title": "MiloOS"',
          '"responseLabel": "MiloOS:"',
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
          '"openAria": "Abrir MiloOS"',
          '"responseLabel": "MiloOS:"',
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
          '"title": "MiloOS"',
          '"tooltip": "ขอความช่วยเหลือ"',
          '"responseLabel": "MiloOS:"',
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
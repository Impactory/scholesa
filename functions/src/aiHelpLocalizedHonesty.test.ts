import fs from 'fs';
import path from 'path';

describe('AI help localized honesty wording', () => {
  const indexSource = fs.readFileSync(path.join(__dirname, 'index.ts'), 'utf8');
  const voiceSystemSource = fs.readFileSync(path.join(__dirname, 'voiceSystem.ts'), 'utf8');

  it('uses the corrected Chinese learner confidence guard copy in callable and voice paths', () => {
    expect(indexSource).toContain('如果你需要完整检查，请老师和你一起看。');
    expect(indexSource).toContain('如果你需要完整檢查，請老師和你一起看。');
    expect(voiceSystemSource).toContain('如果你需要完整检查，请老师和你一起看。');
    expect(voiceSystemSource).toContain('如果你需要完整檢查，請老師和你一起看。');
  });

  it('does not duplicate the Chinese teacher prompt in learner guardrails', () => {
    expect(indexSource).not.toContain('请请老师');
    expect(indexSource).not.toContain('請請老師');
    expect(voiceSystemSource).not.toContain('请请老师');
    expect(voiceSystemSource).not.toContain('請請老師');
  });
});
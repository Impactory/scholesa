import fs from 'node:fs';
import path from 'node:path';

const repoRoot = path.resolve(__dirname, '../..');

describe('flutter web logout availability', () => {
  it('keeps a visible shared header session action for educator web surfaces with custom headers', () => {
    const sessionMenuSource = fs.readFileSync(
      path.join(
        repoRoot,
        'apps/empire_flutter/app/lib/ui/auth/global_session_menu.dart',
      ),
      'utf8',
    );

    expect(sessionMenuSource).toContain('class SessionMenuHeaderAction extends StatelessWidget');
    expect(sessionMenuSource).toContain('showLabel = MediaQuery.sizeOf(context).width >= 960');

    const customHeaderPages = [
      'apps/empire_flutter/app/lib/modules/educator/educator_today_page.dart',
      'apps/empire_flutter/app/lib/modules/educator/educator_learners_page.dart',
      'apps/empire_flutter/app/lib/modules/educator/educator_sessions_page.dart',
      'apps/empire_flutter/app/lib/modules/educator/educator_mission_review_page.dart',
    ];

    for (const relativePath of customHeaderPages) {
      const pageSource = fs.readFileSync(path.join(repoRoot, relativePath), 'utf8');
      expect(pageSource).toContain('SessionMenuHeaderAction(');
    }
  });
});
import fs from 'node:fs';
import path from 'node:path';

const repoRoot = path.resolve(__dirname, '../..');

describe('flutter web logout availability', () => {
  it('keeps the authenticated Flutter shell mounted with a direct shared sign-out control', () => {
    const mainSource = fs.readFileSync(
      path.join(repoRoot, 'apps/empire_flutter/app/lib/main.dart'),
      'utf8',
    );
    const sessionMenuSource = fs.readFileSync(
      path.join(
        repoRoot,
        'apps/empire_flutter/app/lib/ui/auth/global_session_menu.dart',
      ),
      'utf8',
    );

    expect(mainSource).toContain('GlobalSessionMenu(');
    expect(mainSource).toContain('includeSafeArea: false');
    expect(mainSource).toContain('const SizedBox(height: 12)');
    expect(sessionMenuSource).toContain('class SessionSignOutButton extends StatelessWidget');
    expect(sessionMenuSource).toContain('final bool showExplicitSignOut = kIsWeb || width >= 960;');
    expect(sessionMenuSource).toContain('await _confirmGlobalSessionSignOut(effectiveContext);');
    expect(sessionMenuSource).toContain('this.includeSafeArea = true');
    expect(sessionMenuSource).toContain('this.padding = const EdgeInsets.only(top: 16, right: 12)');
    expect(sessionMenuSource).toContain("message: _tGlobalSessionMenu(context, 'Sign Out')");
    expect(sessionMenuSource).toContain("message: _tGlobalSessionMenu(context, 'Account menu')");
  });

  it('keeps a visible shared header session action for educator web surfaces with custom headers', () => {
    const sessionMenuSource = fs.readFileSync(
      path.join(
        repoRoot,
        'apps/empire_flutter/app/lib/ui/auth/global_session_menu.dart',
      ),
      'utf8',
    );

    expect(sessionMenuSource).toContain('class SessionMenuHeaderAction extends StatelessWidget');
    expect(sessionMenuSource).toContain('class SessionSignOutButton extends StatelessWidget');
    expect(sessionMenuSource).toContain('final bool showExplicitSignOut = kIsWeb || width >= 960;');
    expect(sessionMenuSource).toContain("_tGlobalSessionMenu(context, 'Sign Out')");

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
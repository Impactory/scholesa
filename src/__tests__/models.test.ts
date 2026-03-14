import fs from 'fs';
import path from 'path';

describe('Schema model contracts', () => {
  const schemaPath = path.join(process.cwd(), 'schema.ts');
  const schemaSource = fs.readFileSync(schemaPath, 'utf8');

  it('keeps site scoping on core operational records', () => {
    expect(schemaSource).toContain('siteIds: string[]');
    expect(schemaSource).toContain('siteId: string;');
  });

  it('keeps pillar encoding on learning objects', () => {
    const sessionBlock = schemaSource.match(/export interface Session \{[\s\S]*?\n\}/)?.[0] ?? '';
    const missionBlock = schemaSource.match(/export interface Mission \{[\s\S]*?\n\}/)?.[0] ?? '';

    expect(sessionBlock).toContain('pillarCodes: string[]');
    expect(missionBlock).toContain('pillarCodes: string[]');
  });

  it('keeps accountability cycles date-bounded', () => {
    const accountabilityCycleBlock =
      schemaSource.match(/export interface AccountabilityCycle \{[\s\S]*?\n\}/)?.[0] ?? '';

    expect(accountabilityCycleBlock).toContain('startDate: number;');
    expect(accountabilityCycleBlock).toContain('endDate: number;');
    expect(accountabilityCycleBlock).toContain("status: 'active' | 'closed';");
  });
});
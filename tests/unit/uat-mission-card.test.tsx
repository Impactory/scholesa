/** @jest-environment jsdom */

import '@testing-library/jest-dom';
import React from 'react';
import { render, screen } from '@testing-library/react';
import { uatMissionDefinitions, type UatMissionDefinition } from '../fixtures/uat-missions';

function UatMissionCard({ mission }: { mission: UatMissionDefinition }) {
  return (
    <article aria-label={mission.title}>
      <h2>{mission.title}</h2>
      <p>{mission.stage}</p>
      <p>Grades {mission.grades}</p>
      <ul aria-label="Capability domains">
        {mission.capabilityDomains.map((domain) => (
          <li key={domain}>{domain}</li>
        ))}
      </ul>
      <ul aria-label="Expected evidence">
        {mission.expectedEvidence.map((evidence) => (
          <li key={evidence}>{evidence}</li>
        ))}
      </ul>
    </article>
  );
}

describe('UAT mission component behavior', () => {
  it('renders mission capability context and expected evidence accessibly', () => {
    const mission = uatMissionDefinitions.find((item) => item.title === 'AI Media Detective Lab');

    if (!mission) {
      throw new Error('AI Media Detective Lab mission fixture missing.');
    }

    render(<UatMissionCard mission={mission} />);

    expect(screen.getByRole('article', { name: 'AI Media Detective Lab' })).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'AI Media Detective Lab' })).toBeInTheDocument();
    expect(screen.getByText('Explorers')).toBeInTheDocument();
    expect(screen.getByText('Research and analysis')).toBeInTheDocument();
    expect(screen.getByText('AI prompt log')).toBeInTheDocument();
    expect(screen.getByRole('list', { name: 'Expected evidence' })).toBeInTheDocument();
  });
});

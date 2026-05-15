export type MockEvidenceFile = {
  id: string;
  tenantId: string;
  learnerId: string;
  missionId: string;
  checkpointId: string;
  fileName: string;
  contentType: string;
  sizeBytes: number;
  checksum: string;
  url: string;
  createdAt: string;
};

export type UploadEvidenceFileInput = Omit<
  MockEvidenceFile,
  'id' | 'checksum' | 'url' | 'createdAt'
> & {
  body: string;
};

function checksumFor(body: string): string {
  let hash = 0;

  for (let index = 0; index < body.length; index += 1) {
    hash = (hash * 31 + body.charCodeAt(index)) >>> 0;
  }

  return hash.toString(16).padStart(8, '0');
}

export class MockEvidenceStorage {
  private readonly files = new Map<string, MockEvidenceFile>();

  async uploadEvidenceFile(input: UploadEvidenceFileInput): Promise<MockEvidenceFile> {
    const id = `artifact-${this.files.size + 1}`;
    const file: MockEvidenceFile = {
      id,
      tenantId: input.tenantId,
      learnerId: input.learnerId,
      missionId: input.missionId,
      checkpointId: input.checkpointId,
      fileName: input.fileName,
      contentType: input.contentType,
      sizeBytes: input.sizeBytes,
      checksum: checksumFor(input.body),
      url: `mock-storage://${input.tenantId}/${input.learnerId}/${id}/${input.fileName}`,
      createdAt: new Date('2026-05-14T12:05:00.000Z').toISOString(),
    };

    this.files.set(id, file);

    return file;
  }

  getFile(id: string): MockEvidenceFile | undefined {
    return this.files.get(id);
  }

  listFilesForLearner(tenantId: string, learnerId: string): MockEvidenceFile[] {
    return [...this.files.values()].filter(
      (file) => file.tenantId === tenantId && file.learnerId === learnerId
    );
  }

  clear(): void {
    this.files.clear();
  }
}

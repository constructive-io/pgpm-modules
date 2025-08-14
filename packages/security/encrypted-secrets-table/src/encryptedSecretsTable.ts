export type EncryptedSecretRow = {
  id: string;
  secret: string;
};
export function makeRow(id: string, secret: string): EncryptedSecretRow {
  return { id, secret };
}

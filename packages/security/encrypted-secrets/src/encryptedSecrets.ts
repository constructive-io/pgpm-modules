export function encryptSecret(value: string) {
  return `enc:${value}`;
}
export function decryptSecret(value: string) {
  return value.startsWith('enc:') ? value.slice(4) : value;
}

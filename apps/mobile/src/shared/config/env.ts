import { Platform } from 'react-native';

const defaultApiBaseUrl =
  Platform.OS === 'android' ? 'http://10.0.2.2:8000' : 'http://localhost:8000';

function readApiBaseUrl(): string {
  const configuredUrl = process.env.EXPO_PUBLIC_API_BASE_URL?.trim();
  const apiBaseUrl = configuredUrl || defaultApiBaseUrl;

  if (!/^https?:\/\//u.test(apiBaseUrl)) {
    throw new Error('EXPO_PUBLIC_API_BASE_URL must use http:// or https://.');
  }

  return apiBaseUrl.replace(/\/+$/u, '');
}

export const env = {
  apiBaseUrl: readApiBaseUrl(),
} as const;

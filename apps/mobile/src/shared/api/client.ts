import { env } from '@/shared/config/env';

const requestTimeoutMs = 5_000;

interface ApiErrorPayload {
  error?: {
    code?: string;
    message?: string;
    request_id?: string;
  };
}

export interface HealthResponse {
  status: 'ok';
}

export class ApiClientError extends Error {
  readonly code: string;
  readonly requestId?: string;
  readonly status?: number;

  constructor(
    message: string,
    options: { code: string; requestId?: string; status?: number },
  ) {
    super(message);
    this.name = 'ApiClientError';
    this.code = options.code;
    this.requestId = options.requestId;
    this.status = options.status;
  }
}

async function parseError(response: Response): Promise<ApiClientError> {
  let payload: ApiErrorPayload | undefined;

  try {
    payload = (await response.json()) as ApiErrorPayload;
  } catch {
    payload = undefined;
  }

  return new ApiClientError(
    payload?.error?.message ?? '서버 요청에 실패했습니다.',
    {
      code: payload?.error?.code ?? 'HTTP_ERROR',
      requestId: payload?.error?.request_id,
      status: response.status,
    },
  );
}

export async function apiRequest<T>(
  path: `/${string}`,
  init: RequestInit = {},
): Promise<T> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), requestTimeoutMs);

  try {
    const response = await fetch(`${env.apiBaseUrl}${path}`, {
      ...init,
      headers: {
        Accept: 'application/json',
        ...init.headers,
      },
      signal: controller.signal,
    });

    if (!response.ok) {
      throw await parseError(response);
    }

    return (await response.json()) as T;
  } catch (error) {
    if (error instanceof ApiClientError) {
      throw error;
    }

    const isTimeout = error instanceof Error && error.name === 'AbortError';
    throw new ApiClientError(
      isTimeout ? '서버 응답 시간이 초과되었습니다.' : '서버에 연결할 수 없습니다.',
      { code: isTimeout ? 'REQUEST_TIMEOUT' : 'NETWORK_ERROR' },
    );
  } finally {
    clearTimeout(timeoutId);
  }
}

export async function getHealth(): Promise<HealthResponse> {
  return apiRequest<HealthResponse>('/health');
}

import { useCallback, useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { ApiClientError, getHealth } from '@/shared/api/client';
import { env } from '@/shared/config/env';
import { theme } from '@/shared/theme';

type ConnectionStatus = 'checking' | 'online' | 'offline';

interface ConnectionResult {
  status: Exclude<ConnectionStatus, 'checking'>;
  errorMessage?: string;
}

const statusCopy: Record<
  ConnectionStatus,
  { label: string; description: string }
> = {
  checking: {
    label: '확인 중',
    description: 'FastAPI 서버의 응답을 기다리고 있습니다.',
  },
  online: {
    label: '연결됨',
    description: 'FastAPI 서버가 정상적으로 응답했습니다.',
  },
  offline: {
    label: '연결 실패',
    description: '서버 주소와 실행 상태를 확인해 주세요.',
  },
};

async function fetchConnectionResult(): Promise<ConnectionResult> {
  try {
    const health = await getHealth();

    if (health.status !== 'ok') {
      throw new ApiClientError('알 수 없는 서버 상태입니다.', {
        code: 'INVALID_HEALTH_RESPONSE',
      });
    }

    return { status: 'online' };
  } catch (error) {
    return {
      status: 'offline',
      errorMessage:
        error instanceof Error ? error.message : '서버에 연결할 수 없습니다.',
    };
  }
}

export function ServerStatusCard() {
  const [status, setStatus] = useState<ConnectionStatus>('checking');
  const [errorMessage, setErrorMessage] = useState<string>();

  const checkConnection = useCallback(async () => {
    setStatus('checking');
    setErrorMessage(undefined);

    const result = await fetchConnectionResult();
    setStatus(result.status);
    setErrorMessage(result.errorMessage);
  }, []);

  useEffect(() => {
    let isMounted = true;

    void fetchConnectionResult().then((result) => {
      if (isMounted) {
        setStatus(result.status);
        setErrorMessage(result.errorMessage);
      }
    });

    return () => {
      isMounted = false;
    };
  }, []);

  const copy = statusCopy[status];
  const isOnline = status === 'online';
  const isChecking = status === 'checking';

  return (
    <View style={styles.card}>
      <View style={styles.headerRow}>
        <Text style={styles.heading}>서버 연결 상태</Text>
        <View
          accessibilityLabel={`서버 상태: ${copy.label}`}
          style={[
            styles.badge,
            isOnline
              ? styles.onlineBadge
              : isChecking
                ? styles.checkingBadge
                : styles.offlineBadge,
          ]}
        >
          <Text
            style={[
              styles.badgeText,
              isOnline
                ? styles.onlineText
                : isChecking
                  ? styles.checkingText
                  : styles.offlineText,
            ]}
          >
            {copy.label}
          </Text>
        </View>
      </View>

      <Text style={styles.description}>{errorMessage ?? copy.description}</Text>
      <Text selectable style={styles.endpoint}>
        {env.apiBaseUrl}/health
      </Text>

      <Pressable
        accessibilityRole="button"
        disabled={isChecking}
        onPress={() => void checkConnection()}
        style={({ pressed }) => [
          styles.button,
          pressed && styles.buttonPressed,
          isChecking && styles.buttonDisabled,
        ]}
      >
        <Text style={styles.buttonText}>
          {isChecking ? '확인 중…' : '다시 확인'}
        </Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: theme.colors.surface,
    borderColor: theme.colors.border,
    borderRadius: theme.radius.md,
    borderWidth: 1,
    gap: theme.spacing.md,
    padding: theme.spacing.lg,
  },
  headerRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  heading: {
    color: theme.colors.text,
    fontSize: theme.typography.heading,
    fontWeight: '700',
  },
  badge: {
    borderRadius: theme.radius.pill,
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  onlineBadge: {
    backgroundColor: theme.colors.successBackground,
  },
  checkingBadge: {
    backgroundColor: theme.colors.pendingBackground,
  },
  offlineBadge: {
    backgroundColor: theme.colors.dangerBackground,
  },
  badgeText: {
    fontSize: theme.typography.caption,
    fontWeight: '700',
  },
  onlineText: {
    color: theme.colors.success,
  },
  checkingText: {
    color: theme.colors.pending,
  },
  offlineText: {
    color: theme.colors.danger,
  },
  description: {
    color: theme.colors.textMuted,
    fontSize: theme.typography.body,
    lineHeight: 24,
  },
  endpoint: {
    color: theme.colors.textMuted,
    fontSize: theme.typography.caption,
  },
  button: {
    alignItems: 'center',
    backgroundColor: theme.colors.primary,
    borderRadius: theme.radius.sm,
    paddingHorizontal: theme.spacing.md,
    paddingVertical: 14,
  },
  buttonPressed: {
    backgroundColor: theme.colors.primaryPressed,
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  buttonText: {
    color: theme.colors.surface,
    fontSize: theme.typography.body,
    fontWeight: '700',
  },
});

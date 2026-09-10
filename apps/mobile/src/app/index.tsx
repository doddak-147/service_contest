import { Link } from 'expo-router';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ServerStatusCard } from '@/features/foundation/components/server-status-card';
import { theme } from '@/shared/theme';

export default function HomeScreen() {
  return (
    <SafeAreaView edges={['top']} style={styles.safeArea}>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.hero}>
          <Text style={styles.eyebrow}>금융위험 예방 서비스</Text>
          <Text style={styles.title}>투자 전, 손실의 무게를 확인하세요.</Text>
          <Text style={styles.subtitle}>
            현재는 프로젝트 Foundation과 서버 연결만 확인할 수 있습니다.
            금융 분석 기능은 다음 단계에서 추가됩니다.
          </Text>
        </View>

        <ServerStatusCard />

        <Link asChild href="/about">
          <Pressable accessibilityRole="link" style={styles.linkButton}>
            <Text style={styles.linkText}>서비스 원칙 보기</Text>
          </Pressable>
        </Link>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    backgroundColor: theme.colors.background,
    flex: 1,
  },
  content: {
    flexGrow: 1,
    gap: theme.spacing.lg,
    padding: theme.spacing.lg,
  },
  hero: {
    gap: theme.spacing.md,
    paddingBottom: theme.spacing.sm,
    paddingTop: theme.spacing.xl,
  },
  eyebrow: {
    color: theme.colors.primary,
    fontSize: theme.typography.caption,
    fontWeight: '800',
    letterSpacing: 0.6,
  },
  title: {
    color: theme.colors.text,
    fontSize: theme.typography.title,
    fontWeight: '800',
    lineHeight: 39,
  },
  subtitle: {
    color: theme.colors.textMuted,
    fontSize: theme.typography.body,
    lineHeight: 25,
  },
  linkButton: {
    alignItems: 'center',
    padding: theme.spacing.md,
  },
  linkText: {
    color: theme.colors.primary,
    fontSize: theme.typography.body,
    fontWeight: '700',
  },
});

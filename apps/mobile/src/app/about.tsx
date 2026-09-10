import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { theme } from '@/shared/theme';

const principles = [
  '종목이나 매수·매도 시점을 추천하지 않습니다.',
  '미래 주가를 예측하거나 투자 가능 여부를 판단하지 않습니다.',
  '금융 계산은 검증 가능한 코드로 수행합니다.',
  '과거 데이터의 출처와 기준일, 계산 근거를 함께 제공합니다.',
] as const;

export default function AboutScreen() {
  return (
    <SafeAreaView edges={['bottom']} style={styles.safeArea}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.title}>서비스가 지키는 원칙</Text>
        <Text style={styles.description}>
          이 앱은 투자 전에 가정된 손실이 개인의 재무상태에 미칠 충격을
          이해하도록 돕는 교육 목적의 서비스입니다.
        </Text>

        <View style={styles.list}>
          {principles.map((principle, index) => (
            <View key={principle} style={styles.item}>
              <Text style={styles.number}>{index + 1}</Text>
              <Text style={styles.itemText}>{principle}</Text>
            </View>
          ))}
        </View>
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
    gap: theme.spacing.lg,
    padding: theme.spacing.lg,
  },
  title: {
    color: theme.colors.text,
    fontSize: theme.typography.title,
    fontWeight: '800',
  },
  description: {
    color: theme.colors.textMuted,
    fontSize: theme.typography.body,
    lineHeight: 25,
  },
  list: {
    gap: theme.spacing.md,
  },
  item: {
    alignItems: 'flex-start',
    backgroundColor: theme.colors.surface,
    borderColor: theme.colors.border,
    borderRadius: theme.radius.md,
    borderWidth: 1,
    flexDirection: 'row',
    gap: theme.spacing.md,
    padding: theme.spacing.md,
  },
  number: {
    color: theme.colors.primary,
    fontSize: theme.typography.body,
    fontWeight: '800',
  },
  itemText: {
    color: theme.colors.text,
    flex: 1,
    fontSize: theme.typography.body,
    lineHeight: 24,
  },
});

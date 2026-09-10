export const theme = {
  colors: {
    background: '#F4F7F8',
    surface: '#FFFFFF',
    text: '#122229',
    textMuted: '#52636B',
    border: '#D4DEE2',
    primary: '#0E5968',
    primaryPressed: '#094551',
    success: '#167345',
    successBackground: '#E7F6ED',
    danger: '#A9342A',
    dangerBackground: '#FCEDEA',
    pending: '#7A5C12',
    pendingBackground: '#FFF6D8',
  },
  spacing: {
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32,
  },
  radius: {
    sm: 8,
    md: 14,
    pill: 999,
  },
  typography: {
    title: 30,
    heading: 20,
    body: 16,
    caption: 13,
  },
} as const;

export type AppTheme = typeof theme;

/**
 * TomatoBar Personal - Garden Design System & Color Palette
 * 100% matched with FocusCharts.swift & Garden tokens
 */

export interface PaletteColor {
  name: string;
  hex: string;
}

export const GardenPalette: PaletteColor[] = [
  { name: '番茄红', hex: '#B34D3D' }, // rgb(0.70, 0.30, 0.24)
  { name: '鼠尾草绿', hex: '#879C6E' }, // rgb(0.53, 0.61, 0.43)
  { name: '暖黄', hex: '#CFA657' },   // rgb(0.81, 0.65, 0.34)
  { name: '雾蓝', hex: '#7A9EA8' },   // rgb(0.48, 0.62, 0.66)
  { name: '陶土棕', hex: '#B58A66' }, // rgb(0.71, 0.54, 0.40)
  { name: '灰紫', hex: '#A697B3' },   // rgb(0.65, 0.59, 0.70)
  { name: '豆沙粉', hex: '#BF9E8A' }, // rgb(0.75, 0.62, 0.54)
  { name: '松石绿', hex: '#6E8A7A' },  // rgb(0.43, 0.54, 0.48)
];

export const GardenTokens = {
  paper: '#F7F2E8',        // rgb(0.97, 0.94, 0.88)
  surface: '#FAF6EE',      // rgb(0.985, 0.965, 0.925)
  surfaceMuted: '#EFE6D6', // rgb(0.93, 0.88, 0.79)
  ink: '#382A22',          // rgb(0.29, 0.20, 0.15)
  muted: '#8C7764',        // rgb(0.55, 0.47, 0.38)
  line: '#E5DCBE',         // rgb(0.86, 0.81, 0.71)
  red: '#B34D3D',
  redHover: '#9E3E2F',
  cornerSmall: '7px',
  cornerMedium: '10px',
  cornerLarge: '14px',
};

const SUGGESTED_CATEGORIES = ['材料力学', '建模', '英语', '编程', '阅读', '数学', '写作', '开发', '设计'];

export function getCategoryColor(categoryName: string, customStyles?: Record<string, string>): string {
  if (!categoryName || categoryName === '未分类') {
    return GardenTokens.muted;
  }

  // Check custom style if index provided
  if (customStyles && customStyles[categoryName.toLowerCase()]) {
    const val = customStyles[categoryName.toLowerCase()];
    const paletteIdx = parseInt(val, 10);
    if (!isNaN(paletteIdx) && GardenPalette[paletteIdx]) {
      return GardenPalette[paletteIdx].hex;
    }
  }

  const idx = SUGGESTED_CATEGORIES.indexOf(categoryName);
  if (idx >= 0) {
    return GardenPalette[idx % GardenPalette.length].hex;
  }

  // Stable hash
  let hash = 0;
  for (let i = 0; i < categoryName.length; i++) {
    hash = (hash << 5) - hash + categoryName.charCodeAt(i);
    hash |= 0;
  }
  return GardenPalette[Math.abs(hash) % GardenPalette.length].hex;
}

export function getCategorySymbol(categoryName: string): string {
  if (!categoryName || categoryName === '未分类') return 'grid';
  switch (categoryName) {
    case '材料力学':
    case '阅读':
      return 'book';
    case '建模':
      return 'leaf';
    case '英语':
      return 'headphones';
    case '编程':
    case '开发':
      return 'laptop';
    case '数学':
      return 'function';
    case '写作':
      return 'pencil';
    case '设计':
      return 'paintbrush';
    case '机械':
    case '工程':
      return 'gear';
    default:
      return 'tag';
  }
}

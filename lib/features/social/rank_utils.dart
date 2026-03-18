String seasonalRankForXP(int xp) {
  if (xp >= 12000) return 'Mythic';
  if (xp >= 9000) return 'Diamond';
  if (xp >= 6500) return 'Platinum';
  if (xp >= 4200) return 'Gold';
  if (xp >= 2200) return 'Silver';
  return 'Bronze';
}

# Meal Type Bug Debug Guide

## 🐛 **The Issue**

All food items are being added to breakfast regardless of the intended meal type (lunch, dinner, snacks).

## 🔍 **Debug Logging Added**

I've added comprehensive debug logging to track meal type handling:

### **1. FoodLog Initialization**
```
🍽️ FOODLOG INIT DEBUG: Creating food 'Apple' with meal type: Lunch (lunch)
🍽️ FOODLOG INIT DEBUG: Stored raw value: lunch
```

### **2. ViewModel Meal Type Preservation**
```
🍽️ MEAL TYPE DEBUG: Original meal type: Lunch (lunch)
🍽️ MEAL TYPE DEBUG: Original raw value: lunch
🍽️ MEAL TYPE DEBUG: Corrected meal type: Lunch (lunch)
🍽️ MEAL TYPE DEBUG: Corrected raw value: lunch
```

### **3. Meal Type Getter/Setter**
```
🍽️ MEAL TYPE SET DEBUG: Setting meal type for food ID 12345 to Dinner (dinner)
⚠️ MEAL TYPE WARNING: Raw value 'invalid' defaulted to breakfast for food ID 12345
```

## 🧪 **Testing Steps**

1. **Add food to Breakfast**: Should show `meal type: Breakfast (breakfast)`
2. **Add food to Lunch**: Should show `meal type: Lunch (lunch)` 
3. **Add food to Dinner**: Should show `meal type: Dinner (dinner)`
4. **Add food to Snacks**: Should show `meal type: Snacks (snacks)`

## 🎯 **What to Look For**

### **Scenario 1: UI Default Issue**
If you see:
```
🍽️ FOODLOG INIT DEBUG: Creating food 'Apple' with meal type: Breakfast (breakfast)
```
Even when you selected Lunch → **UI is defaulting to breakfast**

### **Scenario 2: Data Corruption Issue**
If you see:
```
🍽️ FOODLOG INIT DEBUG: Creating food 'Apple' with meal type: Lunch (lunch)
⚠️ MEAL TYPE WARNING: Raw value 'invalid' defaulted to breakfast
```
→ **Data is being corrupted during storage**

### **Scenario 3: ViewModel Issue**
If you see:
```
🍽️ MEAL TYPE DEBUG: Original meal type: Lunch (lunch)
🍽️ MEAL TYPE DEBUG: Corrected meal type: Breakfast (breakfast)
```
→ **ViewModel is changing the meal type**

## 🔧 **Expected Fix Based on Results**

### **If UI Default Issue:**
- Fix meal type selection in QuickAddView, FoodDetailView, etc.
- Ensure `selectedMealType` is being set correctly

### **If Data Corruption Issue:**
- Fix the FoodLog model's meal type storage
- Check SwiftData persistence layer

### **If ViewModel Issue:**
- Fix the `createFoodLogForSelectedDate` method
- Ensure meal type is preserved during date correction

## 📊 **Test Now**

Try adding food to different meal types and check the console output. The debug messages will reveal exactly where the meal type is getting lost or defaulted to breakfast.

Once we identify the root cause, I'll provide the targeted fix!
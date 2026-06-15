/// All preset tag categories and options for restaurants and food entries.
/// Both forms import from here so the lists stay consistent.

const Map<String, List<String>> restaurantTagCategories = {
  'Dining Type': [
    'Rice Meal', 'Fine Dining', 'Fast Food', 'Buffet', 'Samgyup',
    'Café', 'Bakery & Pastry', 'Casual Dining', 'Family Restaurant',
    'Food Court', 'Street Food', 'Food Truck', 'All-You-Can-Eat',
    'Brunch Spot', 'Rooftop Dining', 'Waterfront Dining',
    'Themed Restaurant', 'Pop-Up Restaurant',
  ],
  'Cuisine': [
    'Filipino', 'Japanese', 'Korean', 'Chinese', 'Thai', 'Vietnamese',
    'Italian', 'American', 'Mexican', 'Indian', 'French', 'Spanish',
    'Mediterranean', 'Middle Eastern', 'Fusion', 'Taiwanese',
    'Singaporean', 'Malaysian',
  ],
  'Dietary Preferences': [
    'Vegan', 'Vegetarian', 'Gluten-Free', 'Dairy-Free', 'Halal',
    'Keto', 'Low-Carb', 'Organic', 'High Protein', 'Healthy Choice',
    'Nut-Free', 'Pescatarian',
  ],
  'Experience': [
    'Worth the Hype', 'Hidden Gem', 'Must Return', 'First Visit',
    'Date Night', 'Family Gathering', 'Friends Hangout', 'Solo Food Trip',
    'Birthday Celebration', 'Anniversary', 'Comfort Food',
    'Late Night Cravings', 'Bucket List Food', 'Instagrammable',
    'Unexpected Favorite', 'Overrated', 'Underrated', 'Best Value',
    'Expensive but Worth It', 'Would Recommend', 'Cozy Atmosphere',
    'Great Service', 'Quick Service', 'Scenic View', 'Pet Friendly',
    'Kid Friendly', 'Study Spot', 'Work Friendly', 'Romantic', 'Trendy',
  ],
};

const Map<String, List<String>> foodTagCategories = {
  'Food Types': [
    'Rice', 'Burgers', 'Pasta', 'Pizza', 'Fried Chicken', 'Steak',
    'Seafood', 'Noodles', 'Ramen', 'Sushi', 'Dumplings', 'Sandwiches',
    'Tacos', 'Burritos', 'BBQ', 'Hot Pot', 'Curry', 'Salad', 'Soup',
    'Silog', 'Katsu', 'Wings', 'Shawarma', 'Sisig', 'Adobo', 'Sashimi',
  ],
  'Desserts & Snacks': [
    'Cake', 'Cheesecake', 'Ice Cream', 'Gelato', 'Donuts', 'Cookies',
    'Brownies', 'Waffles', 'Pancakes', 'Croissants', 'Pastries', 'Mochi',
    'Halo-Halo', 'Chocolate', 'Frozen Yogurt', 'Cupcakes', 'Macarons',
    'Churros', 'Crepes', 'Fruit Bowl', 'Pudding', 'Pie',
  ],
  'Drinks': [
    'Coffee', 'Milk Tea', 'Fruit Tea', 'Matcha', 'Smoothie', 'Juice',
    'Soda', 'Hot Chocolate', 'Mocktail', 'Cocktail', 'Iced Coffee',
    'Latte', 'Espresso', 'Cappuccino', 'Americano', 'Frappé', 'Lemonade',
    'Energy Drink', 'Protein Shake', 'Tea', 'Sparkling Water',
  ],
};
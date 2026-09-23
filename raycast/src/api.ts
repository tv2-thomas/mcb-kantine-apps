import { environment } from "@raycast/api";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

export const SITE_URL = "https://cozy-shortbread-2866c8.netlify.app/";

type Meal = {
  name: string;
  itemNumber: string;
  categoryName: string;
  description: string;
  allergens: string;
  nutrients: string;
  image: string;
  co2Value: number;
  kcal: number;
};

type MenuResponse = {
  date: string;
  storeDishes: Record<string, Meal[]>;
  allDishes: Record<string, Record<string, Meal[]>>;
};

export type Nutrient = { name: string; value: string; isSubItem: boolean };

export type Dish = {
  id: string;
  category: string;
  name: string;
  description: string;
  allergens: string;
  kcal: number;
  co2: number;
  nutrients: Nutrient[];
  imagePath?: string;
  emoji: string;
};

export type Day = { key: string; date: Date; dishes: Dish[] };

export async function fetchDays(): Promise<Day[]> {
  const response = await fetch(new URL("api", SITE_URL));
  if (!response.ok) throw new Error(`Menu request failed: ${response.status}`);
  const menu = (await response.json()) as MenuResponse;

  const images = new Map<string, string>();
  for (const meal of Object.values(menu.storeDishes).flat()) {
    const path = cacheImage(meal.image);
    if (path) images.set(dishId(meal), path);
  }

  const byDay = { ...menu.allDishes };
  if (!byDay[menu.date] && Object.keys(menu.storeDishes).length > 0) byDay[menu.date] = menu.storeDishes;

  return Object.entries(byDay)
    .map(([key, categories]) => ({
      key,
      date: parseDayKey(key),
      dishes: Object.values(categories)
        .flat()
        .map((meal) => toDish(meal, key === menu.date ? images.get(dishId(meal)) : undefined))
        .sort((a, b) => a.category.localeCompare(b.category, "nb")),
    }))
    .sort((a, b) => a.date.getTime() - b.date.getTime());
}

export function dayKey(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${pad(date.getDate())}-${pad(date.getMonth() + 1)}-${date.getFullYear()}`;
}

export function defaultDayKey(days: Day[]): string | undefined {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return (days.find((d) => d.date >= today) ?? days.at(-1))?.key;
}

export function formatDay(date: Date, style: "short" | "long"): string {
  const text = date.toLocaleDateString("nb-NO", {
    weekday: style === "short" ? "short" : "long",
    day: "numeric",
    month: style === "short" ? "short" : "long",
  });
  return text.charAt(0).toUpperCase() + text.slice(1);
}

export function formatCo2(kg: number): string {
  return kg.toLocaleString("nb-NO", { minimumFractionDigits: 1, maximumFractionDigits: 1 });
}

function parseDayKey(key: string): Date {
  const [day, month, year] = key.split("-").map(Number);
  return new Date(year, month - 1, day);
}

function dishId(meal: Meal): string {
  return `${meal.categoryName}|${meal.itemNumber || meal.name}`;
}

function tidy(text: string | undefined): string {
  return (text ?? "").split(/\s+/).filter(Boolean).join(" ");
}

function toDish(meal: Meal, imagePath: string | undefined): Dish {
  const dish = {
    id: dishId(meal),
    category: tidy(meal.categoryName),
    name: tidy(meal.name),
    description: tidy(meal.description),
    allergens: tidy(meal.allergens),
    kcal: meal.kcal ?? 0,
    co2: meal.co2Value ?? 0,
    nutrients: parseNutrients(meal.nutrients ?? ""),
    imagePath,
  };
  return { ...dish, emoji: emojiFor(`${dish.name} ${dish.category}`) };
}

function parseNutrients(text: string): Nutrient[] {
  return text.split("\n").flatMap((line) => {
    const colon = line.lastIndexOf(": ");
    if (colon < 0) return [];
    const rawName = line.slice(0, colon).trim();
    const isSubItem = rawName.startsWith("-");
    const name = isSubItem ? rawName.slice(1).trim() : rawName;
    return [
      {
        name: name.charAt(0).toUpperCase() + name.slice(1),
        value: line.slice(colon + 2).replaceAll(".", ","),
        isSubItem,
      },
    ];
  });
}

function cacheImage(dataUrl: string | undefined): string | undefined {
  const match = dataUrl?.match(/^data:image\/(\w+);base64,(.+)$/);
  if (!match) return undefined;
  const dir = join(environment.supportPath, "thumbnails");
  const path = join(dir, `${createHash("sha1").update(match[2]).digest("hex")}.${match[1]}`);
  if (!existsSync(path)) {
    mkdirSync(dir, { recursive: true });
    writeFileSync(path, Buffer.from(match[2], "base64"));
  }
  return path;
}

const emojiRules: [string, string[]][] = [
  ["🍕", ["pizza"]],
  ["🍔", ["burger"]],
  ["🌮", ["taco", "burrito", "quesadilla", "nachos", "tortilla"]],
  ["🍣", ["sushi", "poke"]],
  ["🍲", ["suppe", "soup", "gryte", "one pot", "stew", "chili"]],
  ["🍛", ["curry", "tikka", "dal ", "masala"]],
  ["🍜", ["ramen", "nudler", "noodle", "wok", "stir-fry", "pad thai", "udon"]],
  ["🧆", ["falafel"]],
  ["🥗", ["salat", "salad", "bowl"]],
  ["🍝", ["pasta", "spaghetti", "lasagne", "penne", "tagliatelle", "risotto", "gnocchi"]],
  ["🦐", ["reke", "scampi"]],
  ["🐟", ["fisk", "laks", "torsk", "sei", "fish", "tuna", "tunfisk"]],
  ["🍗", ["kylling", "chicken", "kalkun"]],
  ["🥩", ["biff", "storfe", "beef", "lam", "entrecôte", "kjøtt"]],
  ["🐷", ["svin", "pork", "ribbe", "bacon", "skinke"]],
  ["🥙", ["kebab", "gyros", "pita", "wrap"]],
  ["🫘", ["bønne", "kikert", "chickpea", "linse"]],
  ["🥪", ["sandwich", "baguette", "toast"]],
];

function emojiFor(text: string): string {
  const lower = text.toLowerCase();
  return emojiRules.find(([, words]) => words.some((w) => lower.includes(w)))?.[0] ?? "🍽️";
}

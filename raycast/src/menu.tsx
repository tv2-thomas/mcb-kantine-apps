import { Action, ActionPanel, Color, Detail, Icon, Image, Keyboard, List } from "@raycast/api";
import { useCachedPromise } from "@raycast/utils";
import { useState } from "react";
import { pathToFileURL } from "node:url";
import { Day, Dish, SITE_URL, dayKey, defaultDayKey, fetchDays, formatCo2, formatDay } from "./api";

export default function Command() {
  const { data: days = [], isLoading, revalidate } = useCachedPromise(fetchDays, [], { keepPreviousData: true });
  const [selected, setSelected] = useState<string>();
  const day = days.find((d) => d.key === selected) ?? days.find((d) => d.key === defaultDayKey(days));

  return (
    <List
      isLoading={isLoading}
      navigationTitle={day ? formatDay(day.date, "long") : "Kantine"}
      searchBarPlaceholder="Search dishes"
      searchBarAccessory={
        <List.Dropdown tooltip="Day" value={day?.key ?? ""} onChange={setSelected}>
          {days.map((d) => (
            <List.Dropdown.Item
              key={d.key}
              value={d.key}
              title={
                d.key === dayKey(new Date()) ? `I dag - ${formatDay(d.date, "short")}` : formatDay(d.date, "short")
              }
            />
          ))}
        </List.Dropdown>
      }
    >
      {day?.dishes.length === 0 && <List.EmptyView icon="😴" title="Ingen meny denne dagen" />}
      {day?.dishes.map((dish) => (
        <List.Item
          key={dish.id}
          icon={dish.imagePath ? { source: dish.imagePath, mask: Image.Mask.RoundedRectangle } : dish.emoji}
          title={dish.name}
          subtitle={dish.category}
          keywords={[dish.category, dish.description]}
          accessories={[
            ...(dish.kcal > 0 ? [{ tag: { value: `${dish.kcal} kcal`, color: Color.Orange } }] : []),
            ...(dish.co2 > 0 ? [{ tag: { value: `${formatCo2(dish.co2)} kg CO₂`, color: Color.Green } }] : []),
          ]}
          actions={<DishActions dish={dish} day={day} onRefresh={revalidate} />}
        />
      ))}
    </List>
  );
}

function DishActions({
  dish,
  day,
  isDetail,
  onRefresh,
}: {
  dish: Dish;
  day: Day;
  isDetail?: boolean;
  onRefresh?: () => void;
}) {
  return (
    <ActionPanel>
      {!isDetail && (
        <Action.Push title="Show Details" icon={Icon.Sidebar} target={<DishDetail dish={dish} day={day} />} />
      )}
      <Action.OpenInBrowser url={SITE_URL} />
      <Action.CopyToClipboard title="Copy Dish Name" content={dish.name} />
      {onRefresh && (
        <Action
          title="Refresh"
          icon={Icon.ArrowClockwise}
          shortcut={Keyboard.Shortcut.Common.Refresh}
          onAction={onRefresh}
        />
      )}
    </ActionPanel>
  );
}

function DishDetail({ dish, day }: { dish: Dish; day: Day }) {
  const hero = dish.imagePath ? `![](${pathToFileURL(dish.imagePath).href}?raycast-height=260)` : `# ${dish.emoji}`;
  const nutrients = dish.nutrients
    .map((n) => (n.isSubItem ? `| &nbsp;&nbsp;&nbsp;${n.name} | ${n.value} |` : `| **${n.name}** | ${n.value} |`))
    .join("\n");
  const markdown = [
    hero,
    `## ${dish.name}`,
    dish.description,
    nutrients && `### Næringsinnhold per 100 g\n\n| | |\n|:--|--:|\n${nutrients}`,
  ]
    .filter(Boolean)
    .join("\n\n");

  return (
    <Detail
      navigationTitle={dish.name}
      markdown={markdown}
      metadata={
        <Detail.Metadata>
          <Detail.Metadata.Label title="Dag" text={formatDay(day.date, "long")} />
          <Detail.Metadata.TagList title="Kategori">
            <Detail.Metadata.TagList.Item text={dish.category} />
          </Detail.Metadata.TagList>
          {dish.kcal > 0 && <Detail.Metadata.Label title="Energi" text={`${dish.kcal} kcal`} icon={Icon.Bolt} />}
          {dish.co2 > 0 && <Detail.Metadata.Label title="CO₂" text={`${formatCo2(dish.co2)} kg`} icon={Icon.Leaf} />}
          {dish.allergens && (
            <>
              <Detail.Metadata.Separator />
              <Detail.Metadata.TagList title="Allergener">
                {dish.allergens.split(", ").map((a) => (
                  <Detail.Metadata.TagList.Item key={a} text={a} color={Color.Yellow} />
                ))}
              </Detail.Metadata.TagList>
            </>
          )}
        </Detail.Metadata>
      }
      actions={<DishActions dish={dish} day={day} isDetail />}
    />
  );
}

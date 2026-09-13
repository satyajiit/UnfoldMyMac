import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { load } from "cheerio";
import { designs, collectionCategories, collectionDesigns, libraryRoutes } from "../src/lib/design-content";
import { libraryCollections, categoryPath, collectionPath, designPath } from "../src/lib/catalog-routes";
import { site } from "../src/lib/site";

test("every collection, category, and design is crawlable from its parent", () => {
  const hub = load(readFileSync("out/showcase/index.html", "utf8"));
  for (const collection of libraryCollections) {
    const collectionURL = collectionPath(collection);
    assert.ok(hub(`main a[href='${collectionURL}']`).length);
    const $ = load(readFileSync(`out${collectionURL}index.html`, "utf8"));
    assert.equal($(".showcase-grid article").length, collectionDesigns(collection).length);
    for (const category of collectionCategories(collection)) {
      const categoryURL = categoryPath(collection, category);
      assert.ok($(`main a[href='${categoryURL}']`).length);
      const detail = load(readFileSync(`out${categoryURL}index.html`, "utf8"));
      const members = collectionDesigns(collection, category);
      assert.equal(detail(".showcase-grid article").length, members.length);
      for (const { item } of members) assert.equal(detail(`.showcase-grid h3 a[href='${designPath(item)}']`).text(), item.name);
      const schema = detail("script[type='application/ld+json']").toArray().map(node => JSON.parse(detail(node).text())).find(data => data["@type"] === "CollectionPage");
      assert.equal(schema.mainEntity.numberOfItems, members.length);
      assert.deepEqual(schema.mainEntity.itemListElement.map((entry: { url: string }) => entry.url), members.map(({ item }) => `${site.url}${designPath(item)}`));
    }
  }
});

test("each design has app content, a complete breadcrumb trail, and a matching social preview", () => {
  for (const design of designs) {
    const url = designPath(design.item);
    const $ = load(readFileSync(`out${url}index.html`, "utf8"));
    assert.equal($("main h1").text(), design.item.name);
    assert.ok($("main article").text().includes(design.overview.replaceAll("**", "")), url);
    for (const section of design.sections) assert.ok($("main h3").toArray().some(node => $(node).text() === section.title), section.title);
    const schemas = $("script[type='application/ld+json']").toArray().map(node => JSON.parse($(node).text()));
    const crumbs = schemas.find(data => data["@type"] === "BreadcrumbList").itemListElement;
    assert.equal(crumbs.length, 5);
    assert.equal(crumbs.at(-1).item, `${site.url}${url}`);
    for (const crumb of crumbs) assert.ok(libraryRoutes.some(route => `${site.url}${route.path}` === crumb.item) || [site.url + "/", site.url + "/showcase/"].includes(crumb.item));
    const work = schemas.find(data => data["@type"] === "CreativeWork");
    assert.equal(work.name, design.item.name);
    assert.equal(work.image, `${site.url}${design.item.poster}`);
    assert.equal(work.url, `${site.url}${url}`);
    assert.equal($("meta[property='og:image']").attr("content"), work.image);
    const ids = $("[id]").toArray().map(node => $(node).attr("id"));
    assert.equal(new Set(ids).size, ids.length, `Duplicate IDs in ${url}`);
  }
});

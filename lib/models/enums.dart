/// Status of a chapter's translation pipeline.
enum ChapterStatus {
  pending, // not fetched yet
  fetching,
  fetched, // raw source text available
  translating,
  translated,
  failed,
}

/// Which fetch strategy successfully parsed a chapter, kept for debugging
/// and for re-fetching with the same strategy next time.
enum FetchStrategy {
  generic,
  royalRoad,
  webnovelCom,
  novelUpdates, // note: novelupdates is an index site; handled as a special case
  scribbleHub,
  wuxiaWorld,
  shuba69,
  unknown,
}

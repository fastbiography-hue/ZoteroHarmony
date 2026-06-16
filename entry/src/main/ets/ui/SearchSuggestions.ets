/*
 * Search suggestion list used by quick search and advanced search helpers.
 */

@Component
export struct SearchSuggestions {
  @Prop suggestions: string[] = [];
  @StorageLink('zotero_theme') themeMode: string = 'light';
  onPick?: (value: string) => void;

  build() {
    if (this.suggestions.length === 0) {
      Blank()
    } else {
      Column() {
        Text('Suggestions')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : '#777')
          .margin({ left: 12, bottom: 6 })

        Scroll() {
          Column() {
            ForEach(this.suggestions, (suggestion: string) => {
              Row() {
                Text(suggestion)
                  .fontSize(13)
                  .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : '#222')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Blank()
                Text('↵')
                  .fontSize(11)
                  .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : '#999')
              }
              .width('100%')
              .height(32)
              .padding({ left: 12, right: 12 })
              .border({ width: { bottom: 0.5 }, color: this.themeMode === 'dark' ? '#252C38' : '#E9E9E9' })
              .onClick(() => {
                if (this.onPick) {
                  this.onPick(suggestion);
                }
              })
            }, (suggestion: string): string => suggestion)
          }
          .width('100%')
        }
        .height(160)
      }
      .width('100%')
      .backgroundColor(this.themeMode === 'dark' ? '#1B2028' : '#FFFFFF')
      .border({ width: 1, color: this.themeMode === 'dark' ? '#303846' : '#E0E0E0' })
      .borderRadius(8)
      .margin({ left: 12, right: 12, top: 8 })
    }
  }
}

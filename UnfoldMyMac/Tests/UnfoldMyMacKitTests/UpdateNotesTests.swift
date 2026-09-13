import Foundation
import Testing
@testable import UnfoldMyMacKit

@Test func releaseNotesKeepTheirHeadingsAndBullets() {
    let notes = """
    ## Added
    - Creative Scenes
    * Another thing

    Plain paragraph.
    """
    let parsed = UpdateNoteParser.parse(notes, byteLimit: 16_384, lineLimit: 200)
    #expect(parsed.lines == [
        NoteLine(kind: .heading, text: "Added"),
        NoteLine(kind: .bullet, text: "Creative Scenes"),
        NoteLine(kind: .bullet, text: "Another thing"),
        NoteLine(kind: .body, text: "Plain paragraph."),
    ])
    #expect(!parsed.truncated)
}

@Test func imagesInReleaseNotesBecomeTheirTextRatherThanAFetch() {
    let parsed = UpdateNoteParser.parse("- See ![a screenshot](https://example.com/x.png) here",
                                        byteLimit: 16_384, lineLimit: 200)
    #expect(parsed.lines == [NoteLine(kind: .bullet, text: "See a screenshot here")],
            "Nothing in a release description should cause the app to load a remote image")
}

@Test func anEnormousChangelogIsBoundedBeforeItIsEverParsed() {
    let huge = String(repeating: "- a line of notes\n", count: 100_000)
    let parsed = UpdateNoteParser.parse(huge, byteLimit: 16_384, lineLimit: 200)
    #expect(parsed.lines.count <= 200, "A five-thousand-line changelog must not decide the sheet's layout")
    #expect(parsed.truncated, "Whatever is cut has to be offered as a link instead")
}

@Test func emptyNotesProduceNothingRatherThanABlankBullet() {
    #expect(UpdateNoteParser.parse("", byteLimit: 16_384, lineLimit: 200).lines.isEmpty)
    #expect(UpdateNoteParser.parse("\n\n   \n", byteLimit: 16_384, lineLimit: 200).lines.isEmpty)
}

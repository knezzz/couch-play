# Quiz pack format

A quiz pack is either a single `.json` file (text only) or a `.zip` (JSON plus pictures). The host can upload one from the controller. The TV checks it and refuses it with a plain message if anything is wrong.

## The JSON

```json
{
  "format": 1,
  "id": "world-flags",
  "title": "World Flags",
  "questions": [
    {
      "q": "Which country's flag is this?",
      "image": "flags/japan.svg",
      "choices": ["Japan", "Bangladesh", "Palau", "South Korea"],
      "answer": 0
    }
  ]
}
```

| Field | Rule |
|---|---|
| `format` | Must be `1`. |
| `id` | 1–40 characters: lowercase letters, digits, dashes. |
| `title` | Not empty, at most 60 characters. |
| `questions` | At least one. |
| `q` | Not empty. |
| `choices` | Exactly 4, none empty. The TV shuffles them each game. |
| `answer` | Index of the right choice in `choices`: 0, 1, 2 or 3. |
| `image` | Optional. A relative path to an `.svg` inside the zip. No leading `/`, no `..`. |

## The zip

- Exactly one `.json` file at the top level (any name). Other `.json` files in folders are ignored.
- Every `image` path must exist in the zip, for example `flags/japan.svg`.
- Extra files are ignored and never stored.

## Limits

- The file you upload: 5 MB at most.
- Everything inside the zip, unzipped: 20 MB at most.

## Error messages

| Message | Cause |
|---|---|
| The pack is larger than 5 MB. | File over 5 MB. |
| The pack isn't valid JSON. | Not UTF-8 JSON, or not an object. |
| Unsupported pack format. Use "format": 1. | `format` is not 1. |
| The pack id must be lowercase letters, digits or dashes. | Bad `id`. |
| The pack needs a title. | Empty `title`. |
| The pack title must be 60 characters or fewer. | `title` is longer than 60 characters. |
| The pack needs at least one question. | Empty `questions`. |
| Question N: must be an object with q, choices and answer. | The question isn't a JSON object. |
| Question N: the question text is empty. | Empty `q`. |
| Question N: needs exactly 4 non-empty choices. | Wrong `choices`. |
| Question N: answer must be 0, 1, 2 or 3. | Bad `answer`. |
| Question N: image X must be a relative .svg path. | `image` is absolute, has `..`, or isn't `.svg`. |
| Question N: image X is missing from the zip. | No such file in the zip (or a bare `.json` with an image). |
| The zip must contain one .json pack file. | Zero, or more than one, top-level `.json`. |
| The pack is too large when unzipped. | Over 20 MB unzipped, or an entry's real size differs from what it declares. |
| The pack couldn't be read. | Anything else unexpected, such as a damaged zip. |

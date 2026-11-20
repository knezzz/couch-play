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
| `image` | Optional. A relative path to a picture inside the zip: `.svg`, or a photo (`.jpg`, `.jpeg`, `.png`, `.webp`; any letter case). No leading `/`, no `..`. The extension tells the TV which it is; there is no type field. |

## The zip

- Exactly one `.json` file at the top level (any name). Other `.json` files in folders are ignored.
- Every `image` path must exist in the zip, for example `flags/japan.svg`.
- Extra files are ignored and never stored.

## Limits

- The file you upload: 10 MB at most.
- Everything inside the zip, unzipped: 20 MB at most.

## Error messages

The TV shows these in Croatian. They live in `packages/core/lib/strings.dart` (`PackStrings`); N is the question number, X the image path.

| Message | Cause |
|---|---|
| Paket je veći od 10 MB. Smanji ga ili izbaci neke slike pa pokušaj ponovno. | File over 10 MB. |
| Paket nije ispravan JSON. Provjeri da je datoteka tekst (UTF-8) i da počinje znakom {. | Not UTF-8 JSON, or not an object. |
| Nepodržan format paketa. Upiši "format": 1. | `format` is not 1. |
| Oznaka paketa smije imati samo mala slova, brojke i crtice (1 do 40 znakova). | Bad `id`. |
| Paketu treba naslov. Upiši ga u "title". | Empty `title`. |
| Naslov paketa smije imati najviše 60 znakova. | `title` is longer than 60 characters. |
| Paket mora imati barem jedno pitanje. | Empty `questions`. |
| Pitanje N: mora biti objekt s poljima q, choices i answer. | The question isn't a JSON object. |
| Pitanje N: tekst pitanja je prazan. Upiši ga u "q". | Empty `q`. |
| Pitanje N: treba točno 4 odgovora i nijedan ne smije biti prazan. | Wrong `choices`. |
| Pitanje N: "answer" mora biti 0, 1, 2 ili 3. | Bad `answer`. |
| Pitanje N: slika X mora biti relativna putanja do .svg, .jpg, .png ili .webp datoteke. | `image` is absolute, has `..`, or isn't `.svg`, `.jpg`/`.jpeg`, `.png` or `.webp`. |
| Pitanje N: slike X nema u zipu. Dodaj je ili ukloni "image". | No such file in the zip (or a bare `.json` with an image). |
| Zip mora na vrhu sadržavati točno jednu .json datoteku paketa. | Zero, or more than one, top-level `.json`. |
| Paket je prevelik kad se raspakira (najviše 20 MB). Smanji slike. | Over 20 MB unzipped, or an entry's real size differs from what it declares. |
| Paket se ne može pročitati. Provjeri da datoteka nije oštećena. | Anything else unexpected, such as a damaged zip. |

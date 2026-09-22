<div align="center">

<img src=".github/assets/banner.svg" alt="SwingCoach" width="100%">

<br><br>

![Platform](https://img.shields.io/badge/iOS%2018%2B-1F7A46?style=for-the-badge&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-1F7A46?style=for-the-badge&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-1F7A46?style=for-the-badge&logo=swift&logoColor=white)
![Vision](https://img.shields.io/badge/Apple%20Vision-1F7A46?style=for-the-badge&logo=apple&logoColor=white)
![Tests](https://img.shields.io/badge/156%20tests-1F7A46?style=for-the-badge)
![Privacy](https://img.shields.io/badge/100%25%20on--device-1F7A46?style=for-the-badge)

### Film your golf swing with your iPhone. Get one specific thing to fix.

</div>

---

## What it is

SwingCoach turns a phone video of your golf swing into feedback you can actually act on.

Prop your phone up, record a swing, and the app finds your body in every frame, works out where your backswing ends and your downswing begins, and scores six fundamentals against known-good ranges. Then it does the part that matters: instead of dumping six numbers on you, it picks **the single worst fault** and tells you what to work on.

Everything runs on the phone. No account, no upload, no subscription.

## Why I built it

I'm learning to golf, and like everyone else I ended up with a camera roll full of swing videos.

The problem is that watching them back barely helped. I could tell something looked off, but not *what* — and definitely not whether it was better or worse than last week. The apps I found either wanted a subscription, wanted me to upload video of myself to somebody's server, or gave me a wall of numbers without saying which one to care about.

So this is the tool I wanted: record, get one clear thing to fix, and see whether it's improving. It's a passion project I build on evenings and weekends — equal parts learning golf and learning iOS.

## How it works

<img src=".github/assets/pipeline.svg" alt="Record, detect pose, split phases, score checks, coach" width="100%">

Two things it deliberately refuses to do:

- **Guess when it can't see.** If the pose data is too low-confidence or the swing can't be segmented, it says so and asks for a re-record. Confidently wrong feedback is worse than none.
- **Score what the camera can't show.** Hip sway isn't measurable from behind you, so a down-the-line video simply won't report it.

## What it checks

Each check scores 0–100. Which ones run depends on the angle you filmed from.

| Check | What it looks at | Face-on | Down-the-line |
|---|---|:---:|:---:|
| **Setup Posture** | Spine tilt and stance at address | | ✅ |
| **Head Stability** | How much your head drifts during the swing | ✅ | |
| **Hip Sway** | Lateral hip slide vs. rotation | ✅ | |
| **Spine Angle** | Whether you hold your posture through impact | | ✅ |
| **Shoulder Turn** | Rotation at the top of the backswing | ✅ | |
| **Tempo** | Backswing-to-downswing ratio (the classic 3:1) | ✅ | ✅ |

Scores map to three bands — **Good** (70+), **Needs Work** (30–69), **Critical** (under 30) — so the number always matches the words next to it.

## Features

| | |
|---|---|
| 🎥 **120 fps capture** | Slow-motion playback at 0.25x / 0.5x / 1x, or import a clip you already shot |
| 🦴 **Pose overlay** | Skeleton drawn over your swing, with low-confidence joints hidden rather than faked |
| 🏌️ **Club shaft detection** | Estimates shaft angle at address and draws the line on playback |
| ⛳ **Club tracking** | Tag each swing with one of 15 clubs, then filter history and progress by it |
| 📈 **Progress tab** | Per-check trends, a focus area that persists across sessions, and a resettable baseline |
| 🎯 **One fix at a time** | The worst check is surfaced as a single coaching card, not a scoreboard |

## Built with

![Swift](https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-0071E3?style=for-the-badge&logo=swift&logoColor=white)
![SwiftData](https://img.shields.io/badge/SwiftData-0071E3?style=for-the-badge&logo=apple&logoColor=white)
![Vision](https://img.shields.io/badge/Vision-000000?style=for-the-badge&logo=apple&logoColor=white)
![AVFoundation](https://img.shields.io/badge/AVFoundation-000000?style=for-the-badge&logo=apple&logoColor=white)
![Xcode](https://img.shields.io/badge/Xcode-147EFB?style=for-the-badge&logo=xcode&logoColor=white)

## Tools I work with

**Languages**

![Swift](https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white)
![Java](https://img.shields.io/badge/Java%2017-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-025E8C?style=for-the-badge&logo=postgresql&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=for-the-badge&logo=typescript&logoColor=white)
![C](https://img.shields.io/badge/C-00599C?style=for-the-badge&logo=c&logoColor=white)
![C++](https://img.shields.io/badge/C%2B%2B-00599C?style=for-the-badge&logo=cplusplus&logoColor=white)
![C#](https://img.shields.io/badge/C%23-239120?style=for-the-badge&logo=dotnet&logoColor=white)

**Frameworks & Libraries**

![.NET](https://img.shields.io/badge/.NET-512BD4?style=for-the-badge&logo=dotnet&logoColor=white)
![React](https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB)
![PyTorch](https://img.shields.io/badge/PyTorch-EE4C2C?style=for-the-badge&logo=pytorch&logoColor=white)
![TensorFlow](https://img.shields.io/badge/TensorFlow-FF6F00?style=for-the-badge&logo=tensorflow&logoColor=white)
![Keras](https://img.shields.io/badge/Keras-D00000?style=for-the-badge&logo=keras&logoColor=white)
![NumPy](https://img.shields.io/badge/NumPy-013243?style=for-the-badge&logo=numpy&logoColor=white)
![Pandas](https://img.shields.io/badge/Pandas-150458?style=for-the-badge&logo=pandas&logoColor=white)
![JUnit5](https://img.shields.io/badge/JUnit5-25A162?style=for-the-badge&logo=junit5&logoColor=white)

**Infrastructure & Data**

![Kafka](https://img.shields.io/badge/Apache%20Kafka-231F20?style=for-the-badge&logo=apachekafka&logoColor=white)
![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge)
![Azure](https://img.shields.io/badge/Azure-0078D4?style=for-the-badge)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Datadog](https://img.shields.io/badge/Datadog-632CA6?style=for-the-badge&logo=datadog&logoColor=white)
![Flyway](https://img.shields.io/badge/Flyway-CC0200?style=for-the-badge&logo=flyway&logoColor=white)

**Tooling**

![Git](https://img.shields.io/badge/Git-F05032?style=for-the-badge&logo=git&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)
![GitLab](https://img.shields.io/badge/GitLab-FC6D26?style=for-the-badge&logo=gitlab&logoColor=white)
![Azure DevOps](https://img.shields.io/badge/Azure%20DevOps-0078D7?style=for-the-badge)
![Jira](https://img.shields.io/badge/Jira-0052CC?style=for-the-badge&logo=jira&logoColor=white)
![VS Code](https://img.shields.io/badge/VS%20Code-0078D4?style=for-the-badge)
![macOS](https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white)

## Running it

Requires **Xcode 16+**, **iOS 18+**, and a real device — pose detection needs a camera, and the simulator has no 120 fps format.

```bash
git clone https://github.com/GeorgeFashho/SwingCoach.git
cd SwingCoach
open SwingCoach.xcodeproj
```

Set your own signing team under **Signing & Capabilities**, then build and run to your iPhone.

> **Filming tip:** phone 8–10 feet away at roughly hand height, with your whole body in frame. The app's onboarding walks through both angles.

## Project structure

```
SwingCoach/
├── Models/          SwiftData models + domain enums
├── Services/        The engine room — pose, segmentation, analysis, coaching
│   └── Checks/      One file per biomechanical check
├── ViewModels/      Capture, playback, progress
├── Views/           SwiftUI screens by feature
├── DesignSystem/    Spacing, radius, color, and type tokens
└── Utilities/       Angle math, smoothing, and all tunable thresholds
```

The analysis layer (`AnalysisEngine`, `CoachingEngine`, the checks, segmentation) is pure and SwiftData-free, which is why it can be tested against synthetic swing fixtures — **156 tests across 31 suites**. Every threshold lives in `Utilities/Constants.swift` rather than scattered through the code.

## Privacy

Videos, pose data, and results never leave the device. They live in the app's own Documents directory, and deleting a swing deletes its video and pose file with it. No analytics, no account, and no network layer in the app at all.

---

<div align="center">
<sub>A passion project by <a href="https://github.com/GeorgeFashho">George Fashho</a> — built on evenings and weekends.</sub>
</div>

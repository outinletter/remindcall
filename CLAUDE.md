# RemindCall

## 개요·기술 스택
- 통화 전·중에 상대의 번호, 생일, 메모, 연락 기록을 카드로 보여 주는 앱. 기획은 `PLAN.md`.
- SwiftUI, 최소 iOS 17, SwiftData + CloudKit(개인 DB, 컨테이너 `iCloud.com.addvalue.remindcall`)
- 번들 ID `com.addvalue.remindcall`, 팀 `A7QB8PT33N`
- 연락처는 `Contacts` 프레임워크로 읽기만 한다. 앱 데이터는 별도 모델에 저장한다.

## 폴더 구조
- `RemindCall/Models` SwiftData 모델, `PhoneKey`, 컨테이너 생성
- `RemindCall/Services` 연락처 로딩·검색(`ContactsStore`)
- `RemindCall/Views` 연락처 목록, 통화 화면 스타일 카드(`CallCardView`, `Cards`)
- `RemindCall.entitlements` iCloud(CloudKit), 푸시

## 규칙
- iOS가 허용하지 않는 기능은 만들지 않는다: 시스템 통화 기록·문자 읽기, 수신 번호 가로채기, 통화 화면 오버레이, 통화 녹음, 연락처 기본 메모 필드.
- 통화는 `tel://`로 시스템 전화 앱에 넘긴다. 음소거·키패드 같은 통화 제어 버튼은 만들지 않는다.
- 통화 기록은 앱에서 건 통화만 저장하고, 화면에 그렇게 밝힌다.
- CloudKit 조건: 모델 속성은 모두 기본값을 가지고 unique 제약을 쓰지 않는다.
- 앱 데이터와 연락처는 번호 키(`PhoneKey.make`: 숫자만, 82→0)로 연결한다. `CNContact.identifier`는 기기마다 달라 키로 쓰지 않는다.
- 연락처 원본을 서버로 보내거나 수정하지 않는다.

## 명령어·현재 상태
- 스킴·타깃: `RemindCall`, 프로젝트 `RemindCall.xcodeproj` (폴더 동기화 그룹: `RemindCall/` 안에 파일을 만들면 자동 포함)
- 기기 빌드: `xcodebuild ... -destination 'id=<UDID>' -allowProvisioningUpdates` (xcodebuild용 UDID는 `-showdestinations`로, devicectl용 ID는 `devicectl list devices`로 확인)
- 현재: 하단 4탭, 카드 화면 별 버튼·스와이프 닫기, 연락처 정렬 5종(`ContactSort`, 설정 `@AppStorage`) 구현. 마지막 실기기 설치는 정렬 추가 전 버전. 다음: 재설치 후 정렬·제스처 감도 확인.
- 시뮬레이터는 쓰지 않는다. 실기기 설치는 "설치" 요청 때만 한다.

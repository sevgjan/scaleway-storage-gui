# Scaleway Object Storage Browser for macOS
A native macOS app that browses Scaleway Object Storage (S3 compatible) with a modern SwiftUI UX.
Target: minimal, premium alternative to Cyberduck or Transmit focused on Scaleway.

## Goals
• Fast bucket and object browsing
• Upload, download, delete, rename, create folder placeholder
• Search and filter
• Presigned URL generation
• Secure credential storage in Keychain
• Works across Scaleway regions via configurable endpoint

## Non goals
• Full S3 admin console replacement
• Multi account team management in v1
• Advanced IAM features
• Multipart tuning beyond basic defaults

## Primary user flows
1. First launch setup
   • User enters Access Key, Secret Key
   • Select region endpoint (nl ams, fr par, pl waw)
   • Save in Keychain
   • Verify credentials by listing buckets

2. Browse
   • Sidebar shows buckets
   • Main view shows objects at prefix
   • Breadcrumb navigation for prefixes
   • Sorting by name, size, last modified

3. File operations
   • Upload files and folders, drag and drop
   • Download selection to local folder
   • Delete with confirmation
   • Rename object
   • Create folder placeholder by uploading zero byte object ending with slash

4. Utility operations
   • Copy object URL
   • Generate presigned URL with expiry
   • View metadata and headers
   • Show storage class if available

## UX blueprint
• Window layout
  • Left sidebar: Accounts and Buckets
  • Top bar: Breadcrumbs, Search, Actions
  • Main table: Name, Size, Modified, Type
  • Right inspector: Metadata, Preview, Actions

• Key interactions
  • Double click folder to enter prefix
  • Cmd Back to go up
  • Drag files into table to upload
  • Context menu on object for actions

## Technical architecture
### Approach
Use AWS SDK for Swift configured to use a custom S3 endpoint for Scaleway.
Fallback plan: implement direct REST calls with AWS Signature V4 if the SDK becomes limiting.

### Modules
1. AppUI
   • SwiftUI views, navigation, table, inspector
2. StorageCore
   • S3 client wrapper, endpoint config, requests, pagination, uploads
3. AuthKeychain
   • Keychain read write, account profiles
4. Models
   • Bucket, ObjectItem, Prefix, TransferTask, Errors
5. Transfers
   • Upload and download manager with progress and cancellation
6. Logging
   • OSLog structured logs, optional debug panel

### State management
• SwiftUI + Observation or Combine
• Central AppStore
  • accounts
  • selectedAccount
  • buckets
  • selectedBucket
  • currentPrefix
  • objectList
  • transfers
  • uiState and errors

## Data models
### AccountProfile
• id
• displayName
• accessKeyId
• secretKeyRef (Keychain key)
• endpointURL
• regionIdentifier string for signing
• createdAt

### BucketItem
• name
• createdAt optional

### ObjectItem
• key
• size
• lastModified
• eTag
• contentType optional
• isFolder inferred by key suffix slash and size zero

### TransferTask
• id
• direction upload or download
• objectKey
• localURL
• progress 0 to 1
• state queued running paused failed done
• error optional

## Endpoint and region handling
Scaleway S3 style endpoints commonly look like:
• https://s3.nl-ams.scw.cloud
• https://s3.fr-par.scw.cloud
• https://s3.pl-waw.scw.cloud

Signing region
Some S3 compatible providers accept any region string, but safest is to use the expected region if documented.
Implementation should allow user selection and store it per account.

Config fields per account:
• endpointURL
• signingRegion string

## S3 operations needed
### Buckets
• ListBuckets

### Objects
• ListObjectsV2 with prefix and delimiter
• HeadObject for metadata
• GetObject for download
• PutObject for upload
• DeleteObject
• CopyObject for rename
  • rename is CopyObject to new key then Delete old key

### Presigned URLs
• Presign GetObject and optionally PutObject
• expiry selectable 5 min, 1 h, 24 h

### Folder creation
• PutObject with key ending in slash and empty body

## Pagination and listing
Use ListObjectsV2 with:
• prefix currentPrefix
• delimiter slash to get common prefixes
• maxKeys 1000
Handle ContinuationToken.
UI should load first page quickly then fetch remaining pages in background with incremental updates.

## Transfers
### Upload
• Small files use PutObject
• Large files use Multipart upload
  • threshold 64 MB configurable
  • parts 8 to 16 MB
  • show progress by bytes sent
• Support folder upload by enumerating local directory and mapping to prefix

### Download
• GetObject streaming to disk
• Support parallel downloads with a queue
• Allow cancel

### Concurrency
• Use async await
• Use TaskGroup for parallel operations with a limit

## Security
• Store Secret Key only in Keychain
• Never log credentials
• Allow user to remove account and wipe Keychain entry
• Optional toggle for remember last used bucket and prefix

## Error handling
Map errors into user friendly banners:
• Invalid credentials
• Endpoint unreachable
• Permission denied
• Object not found
• Timeout and retry suggestion

Add retry policy:
• network errors retry 3 times with backoff
• do not retry auth failures

## Implementation steps
### Phase 0: Project setup
1. Create macOS SwiftUI app
2. Add AWS SDK for Swift dependency
3. Add Keychain helper
4. Add OSLog logger
5. Create basic navigation layout

### Phase 1: Accounts and Keychain
1. Account creation screen
2. Save secret in Keychain, store access key and endpoint in app storage
3. Test connection button calls ListBuckets
4. Account list and switch

### Phase 2: Bucket list and browsing
1. Load buckets into sidebar
2. On bucket select, list root objects with delimiter
3. Implement breadcrumb and prefix navigation
4. Implement sorting and refresh

### Phase 3: Object actions
1. Download
2. Delete
3. Rename via CopyObject + Delete
4. Create folder placeholder

### Phase 4: Upload
1. Drag and drop files
2. Upload progress UI
3. Multipart upload for large files

### Phase 5: Inspector and previews
1. HeadObject metadata display
2. Quick preview for images and text
3. Copy key and copy URL buttons

### Phase 6: Presigned URLs
1. Generate presigned GetObject URL
2. Expiry picker
3. Copy to clipboard

### Phase 7: Polishing
1. Keyboard shortcuts
2. Context menus
3. Better empty states
4. Preferences panel for defaults

## Milestones
MVP
• Account setup
• List buckets
• Browse objects with prefix navigation
• Upload, download, delete
• Basic progress

v1
• Rename
• Search
• Presigned URLs
• Inspector metadata

v1.5
• Multipart tuning
• Folder upload
• Preview enhancements

## Testing strategy
• Unit tests for key mapping and rename logic
• Integration tests using a test bucket
• Manual testing for large file multipart, flaky networks, cancel and retry

## Deliverables for Codex
• SwiftUI macOS app skeleton with navigation
• StorageCore module with S3 client wrapper
• Keychain account storage
• Initial bucket list and object list working against Scaleway endpoint
• Basic download and upload with progress
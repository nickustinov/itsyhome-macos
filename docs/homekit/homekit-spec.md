# HomeKit Accessory Protocol Specification
## Non-Commercial Version
##### Release R2  Developer


#### **Contents**

**1** **Introduction** **18**
1.1 Purpose of This Specification . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 18
1.2 Requirements, Recommendations, and Permissions . . . . . . . . . . . . . . . . . . . . . . . . 18
1.3 Terminology . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 18
1.3.1 Accessory, Device, and Product . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 18
1.3.2 Component . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 19
1.3.3 Feature . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 19


**2** **Core Concepts** **20**
2.1 Transports . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 20
2.2 Security . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 20
2.2.1 Pairing . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 20
2.2.1.1 Pair Setup . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 20
2.2.1.2 Pair Verify . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 20
2.2.2 Session Keys . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 20
2.3 Attributes . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 21
2.3.1 Accessories . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 21
2.3.2 Services . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 21
2.3.2.1 Service Naming . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 21
2.3.2.2 Extending Services . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 21
2.3.2.3 Primary Service . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 21
2.3.2.4 Hidden Service . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 22
2.3.2.5 Linked Service . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 22
2.3.3 Characteristics . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 22
2.3.3.1 Valid Characteristic Values . . . . . . . . . . . . . . . . . . . . . . . . . . . 23
2.3.3.2 Additional Authorization Data . . . . . . . . . . . . . . . . . . . . . . . . . . 23
2.3.4 Additional HomeKit Accessory Protocol Requirements . . . . . . . . . . . . . . . . . . . 24
2.4 Profiles . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 24
2.5 Roles . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 24
2.5.1 HAP Client . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 24
2.5.2 HAP Accessory Server . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 24
2.5.3 HAP Accessory Objects . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 25
2.5.3.1 Required Services . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 25
2.5.3.2 Bridges . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 25
2.5.3.3 Primary HAP Accessory Object . . . . . . . . . . . . . . . . . . . . . . . . . 25
2.5.3.4 Colocation . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 25
2.6 Accessory Attribute Database . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 26
2.6.1 Instance IDs . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 26


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


2


CONTENTS


2.6.1.1 Accessory Instance IDs . . . . . . . . . . . . . . . . . . . . . . . . . . . . 26
2.6.1.2 Service and Characteristic Instance IDs . . . . . . . . . . . . . . . . . . . . 26


**3** **Requirements** **27**
3.1 Overview . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 27
3.2 General Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 27
3.3 Wi-Fi Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 27
3.4 Firmware Updates . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 27
3.5 Coalescing Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 27


**4** **Accessory Setup** **29**
4.1 Overview . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 29
4.2 Setup Payload . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 29
4.2.1 Setup Code . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 29
4.2.1.1 Generation of Setup Code . . . . . . . . . . . . . . . . . . . . . . . . . . . 29
4.2.1.2 Invalid Setup Codes . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 29


**5** **Pairing** **31**
5.1 Overview . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 31
5.2 Cryptographic Key Storage . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 31
5.3 Admins . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 31
5.4 Device ID . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 31
5.5 Secure Remote Password (SRP) . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 31
5.5.1 SRP Modifications . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 31
5.5.2 SRP Test Vectors . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 32
5.6 Pair Setup . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 34
5.6.1 M1: iOS Device - _>_ Accessory – ‘SRP Start Requestʼ . . . . . . . . . . . . . . . . . . . . 34
5.6.2 M2: Accessory - _>_ iOS Device – ‘SRP Start Responseʼ . . . . . . . . . . . . . . . . . . . 34
5.6.3 M3: iOS Device - _>_ Accessory – ‘SRP Verify Requestʼ . . . . . . . . . . . . . . . . . . . 36
5.6.4 M4: Accessory - _>_ iOS Device – ‘SRP Verify Responseʼ . . . . . . . . . . . . . . . . . . 36
5.6.5 M5: iOS Device - _>_ Accessory – ‘Exchange Requestʼ . . . . . . . . . . . . . . . . . . . 37
5.6.5.1 _<_ _`M4`_ _>_ Verification . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 37
5.6.5.2 _<_ _`M5`_ _>_ Request Generation . . . . . . . . . . . . . . . . . . . . . . . . . . 37
5.6.6 M6: Accessory - _>_ iOS Device – ‘Exchange Responseʼ . . . . . . . . . . . . . . . . . . . 38
5.6.6.1 _<_ _`M5`_ _>_ Verification . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 38
5.6.6.2 _<_ _`M6`_ _>_ Response Generation . . . . . . . . . . . . . . . . . . . . . . . . . . 38
5.6.6.3 _<_ _`M6`_ _>_ Verification by iOS Device . . . . . . . . . . . . . . . . . . . . . . . 39
5.7 Pair Verify . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 39
5.7.1 M1: iOS Device - _>_ Accessory – ‘Verify Start Requestʼ . . . . . . . . . . . . . . . . . . . 40
5.7.2 M2: Accessory - _>_ iOS Device – ‘Verify Start Responseʼ . . . . . . . . . . . . . . . . . . 40
5.7.3 M3: iOS Device - _>_ Accessory – ‘Verify Finish Requestʼ . . . . . . . . . . . . . . . . . . 41
5.7.4 M4: Accessory - _>_ iOS Device – ‘Verify Finish Responseʼ . . . . . . . . . . . . . . . . . 41
5.8 Fragmentation and Reassembly . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 42
5.9 AEAD Algorithm . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 42
5.10 Add Pairing . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 43
5.10.1 M1: iOS Device - _>_ Accessory – ‘Add Pairing Requestʼ . . . . . . . . . . . . . . . . . . . 43
5.10.2 M2: Accessory - _>_ iOS Device – ‘Add Pairing Responseʼ . . . . . . . . . . . . . . . . . . 43
5.11 Remove Pairing . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 44


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


3


CONTENTS


5.11.1 M1: iOS Device - _>_ Accessory – ‘Remove Pairing Requestʼ . . . . . . . . . . . . . . . . . 44
5.11.2 M2: Accessory - _>_ iOS Device – ‘Remove Pairing Responseʼ . . . . . . . . . . . . . . . . 45
5.12 List Pairings . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 45
5.12.1 M1: iOS Device - _>_ Accessory – ‘List Pairings Requestʼ . . . . . . . . . . . . . . . . . . 46
5.12.2 M2: Accessory - _>_ iOS Device – ‘List Pairings Responseʼ . . . . . . . . . . . . . . . . . 46
5.13 Pairing over Bluetooth LE . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 46
5.13.1 Pairing Service . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 47
5.13.1.1 Pair Setup . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 47
5.13.1.2 Pair Verify . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 47
5.13.1.3 Pairing Features . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 47
5.13.1.4 Pairing Pairings . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 48
5.14 Pairing over IP . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 48
5.15 Methods, Error Codes, and TLV Values . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 49


**6** **HomeKit Accessory Protocol for IP Accessories** **52**
6.1 Overview . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 52
6.2 Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 52
6.2.1 IP Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 52
6.2.2 Bonjour Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 52
6.2.3 TCP Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 52
6.2.4 HTTP Server Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 53
6.2.5 Application Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 53
6.2.6 General Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 53
6.3 HAP Objects . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 53
6.3.1 Accessory Objects . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 53
6.3.2 Service Objects . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 54
6.3.3 Characteristic Objects . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 54
6.4 Discovery . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 57
6.5 Security for IP Accessories . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 59
6.5.1 Pairing . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 59
6.5.2 Session Security . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 59
6.6 IP Accessory Attribute Database . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 60
6.6.1 Service and Characteristic Types . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 60
6.6.2 Getting the Accessory Attribute Database . . . . . . . . . . . . . . . . . . . . . . . . . 61
6.6.3 IP Protocol Version . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 61
6.6.4 Example Accessory Attribute Database in JSON . . . . . . . . . . . . . . . . . . . . . . 61
6.7 Controlling IP Accessories . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 66
6.7.1 Handling HTTP Requests . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 66
6.7.1.1 Successful HTTP Status Codes . . . . . . . . . . . . . . . . . . . . . . . . 66
6.7.1.2 Client Error HTTP Status Codes . . . . . . . . . . . . . . . . . . . . . . . . 66
6.7.1.3 Server Error Status HTTP Codes . . . . . . . . . . . . . . . . . . . . . . . . 66
6.7.1.4 HAP Status Codes . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 67
6.7.2 Writing Characteristics . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 67
6.7.2.1 Characteristic Write Request Objects . . . . . . . . . . . . . . . . . . . . . . 68
6.7.2.2 Write a Single Characteristic . . . . . . . . . . . . . . . . . . . . . . . . . . 68
6.7.2.3 Writing Multiple Characteristics . . . . . . . . . . . . . . . . . . . . . . . . 69
6.7.2.4 Timed Write Procedures . . . . . . . . . . . . . . . . . . . . . . . . . . . . 71
6.7.3 Writing a Characteristic with Write Response . . . . . . . . . . . . . . . . . . . . . . . 73


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


4


CONTENTS


6.7.4 Reading Characteristics . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 73
6.7.4.1 Reading a Single Characteristic . . . . . . . . . . . . . . . . . . . . . . . . 74
6.7.4.2 Reading Multiple Characteristics . . . . . . . . . . . . . . . . . . . . . . . . 75
6.7.5 Control Point Characteristics . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 76
6.7.6 Identify Routine . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 76
6.7.7 Identify HTTP URL . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 76
6.8 Notifications . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 77
6.8.1 Accessory Updates State Number Internally . . . . . . . . . . . . . . . . . . . . . . . . 77
6.8.2 Accessory Sends Events to Controller . . . . . . . . . . . . . . . . . . . . . . . . . . . 77
6.8.2.1 Event Example . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 78
6.8.2.2 Event Policy . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 79
6.9 HTTP URLs . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 79
6.10 HomeKit Data Stream . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 80
6.10.1 Data Stream Transport Security . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 80
6.10.2 Frame Format . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 81
6.10.3 Payload Format . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 82
6.10.3.1 Messages . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 82
6.10.3.1.1 Event Messages . . . . . . . . . . . . . . . . . . . . . . . . . . . 82
6.10.3.2 Request Messages . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 83
6.10.3.2.1 Response Messages . . . . . . . . . . . . . . . . . . . . . . . . . 83
6.10.3.2.2 Hello . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 84
6.10.4 Data Format . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 84
6.11 Testing IP Accessories . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 86


**7** **HomeKit Accessory Protocol for Bluetooth LE Accessories** **88**
7.1 Overview . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 88
7.2 Accessory Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 88
7.3 HAP for Bluetooth LE . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 88
7.3.1 HAP Transactions and Procedures . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 88
7.3.2 Attribute Database Authentication . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 89
7.3.3 HAP PDU Format . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 89
7.3.3.1 HAP PDU Header - Control Field . . . . . . . . . . . . . . . . . . . . . . . . 89
7.3.3.2 HAP Request Format . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 90
7.3.3.3 HAP Response Format . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 91
7.3.3.4 HAP PDU Body . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 91
7.3.3.5 HAP PDU Fragmentation Scheme . . . . . . . . . . . . . . . . . . . . . . . 92
7.3.4 HAP-BLE PDU Payloads . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 93
7.3.4.1 HAP-Characteristic-Signature-Read-Request . . . . . . . . . . . . . . . . . 93
7.3.4.2 HAP-Characteristic-Signature-Read-Response . . . . . . . . . . . . . . . . 93
7.3.4.3 HAP-Characteristic-Signature-Read-Response (with Valid Values) . . . . . . . 94
7.3.4.4 HAP-Characteristic-Write-Request . . . . . . . . . . . . . . . . . . . . . . . 94
7.3.4.5 HAP-Characteristic-Write-Response . . . . . . . . . . . . . . . . . . . . . . 95
7.3.4.6 HAP-Characteristic-Read-Request . . . . . . . . . . . . . . . . . . . . . . . 95
7.3.4.7 HAP-Characteristic-Read-Response . . . . . . . . . . . . . . . . . . . . . . 95
7.3.4.8 HAP-Characteristic-Timed-Write-Request . . . . . . . . . . . . . . . . . . . 95
7.3.4.9 HAP-Characteristic-Timed-Write-Response . . . . . . . . . . . . . . . . . . 96
7.3.4.10 HAP-Characteristic-Execute-Write-Request . . . . . . . . . . . . . . . . . . 96
7.3.4.11 HAP-Characteristic-Execute-Write-Response . . . . . . . . . . . . . . . . . 96


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


5


CONTENTS


7.3.4.12 HAP-Service-Signature-Read-Request . . . . . . . . . . . . . . . . . . . . . 96
7.3.4.13 HAP-Service-Signature-Read-Response . . . . . . . . . . . . . . . . . . . . 97
7.3.4.14 HAP-Characteristic-Configuration-Request . . . . . . . . . . . . . . . . . . 97
7.3.4.15 HAP-Characteristic-Configuration-Response . . . . . . . . . . . . . . . . . 98
7.3.4.16 HAP-Protocol-Configuration-Request . . . . . . . . . . . . . . . . . . . . . 98
7.3.4.17 HAP-Protocol-Configuration-Response . . . . . . . . . . . . . . . . . . . . 99
7.3.5 HAP Procedures . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 99
7.3.5.1 HAP Characteristic Signature Read Procedure . . . . . . . . . . . . . . . . . 99
7.3.5.2 HAP Characteristic Write Procedure . . . . . . . . . . . . . . . . . . . . . . 101
7.3.5.3 HAP Characteristic Read Procedure . . . . . . . . . . . . . . . . . . . . . . 102
7.3.5.4 HAP Characteristic Timed Write Procedure . . . . . . . . . . . . . . . . . . . 102
7.3.5.5 HAP Characteristic Write-with-Response Procedure . . . . . . . . . . . . . . 104
7.3.5.6 HAP Fragmented Writes . . . . . . . . . . . . . . . . . . . . . . . . . . . . 108
7.3.5.7 HAP Fragmented Read . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 109
7.3.5.8 HAP Characteristic Configuration Procedure . . . . . . . . . . . . . . . . . . 109
7.3.5.9 HAP Protocol Configuration Procedure . . . . . . . . . . . . . . . . . . . . . 110
7.3.6 HAP Status Codes . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 110
7.3.7 Pair-Resume Procedure . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 110
7.3.7.1 Accessory Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . 110
7.3.7.2 Defines . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 111
7.3.7.3 Initial SessionID . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 111
7.3.7.4 Pair Resume . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 111
7.3.7.4.1 M1: Controller -> Accessory - Resume Request . . . . . . . . . . . 113
7.3.7.4.2 M2: Accessory -> Controller - Resume Response . . . . . . . . . . 114
7.3.7.5 Compute Shared Secret . . . . . . . . . . . . . . . . . . . . . . . . . . . . 115
7.4 Bluetooth LE . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 115
7.4.1 General requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 115
7.4.1.1 Accessory Role . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 115
7.4.1.2 Bluetooth Device Address . . . . . . . . . . . . . . . . . . . . . . . . . . . 116
7.4.1.3 Advertising Channels . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 116
7.4.1.4 Advertising Interval . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 116
7.4.1.5 Transmission Power . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 116
7.4.1.6 MTU Size . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 116
7.4.1.7 Maximum Payload Size . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 116
7.4.1.8 Global State Number (GSN) . . . . . . . . . . . . . . . . . . . . . . . . . . 117
7.4.1.9 Unpaired Identify . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 117
7.4.2 HAP BLE Advertisement Formats . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 117
7.4.2.1 HAP BLE Regular Advertisement Format . . . . . . . . . . . . . . . . . . . . 117
7.4.2.1.1 Flags . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 117
7.4.2.1.2 Manufacturer Data . . . . . . . . . . . . . . . . . . . . . . . . . 118
7.4.2.1.3 Local Name . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 119
7.4.2.2 HAP BLE Encrypted Notification Advertisement Format . . . . . . . . . . . . . 119
7.4.2.2.1 Flags . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 119
7.4.2.2.2 Manufacturer Data . . . . . . . . . . . . . . . . . . . . . . . . . 120
7.4.3 HAP-BLE Protocol Information Service . . . . . . . . . . . . . . . . . . . . . . . . . . . 121
7.4.3.1 BLE Protocol Version Characteristic . . . . . . . . . . . . . . . . . . . . . . 121
7.4.3.2 Service Signature Characteristic . . . . . . . . . . . . . . . . . . . . . . . . 121
7.4.4 Attributes of HAP Services and Characteristics . . . . . . . . . . . . . . . . . . . . . . 121


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


6


CONTENTS


7.4.4.1 HAP Services and HAP Characteristics . . . . . . . . . . . . . . . . . . . . . 121
7.4.4.2 Instance IDs . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 122
7.4.4.3 Service Instance ID . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 122
7.4.4.4 HAP Service Properties . . . . . . . . . . . . . . . . . . . . . . . . . . . . 122
7.4.4.4.1 HAP Linked Services . . . . . . . . . . . . . . . . . . . . . . . . 122
7.4.4.5 Characteristic Descriptors included in the GATT Database . . . . . . . . . . . 123
7.4.4.5.1 Bluetooth LE Characteristic Properties . . . . . . . . . . . . . . . 123
7.4.4.5.2 Characteristic Instance ID . . . . . . . . . . . . . . . . . . . . . . 123
7.4.4.5.3 Client Characteristic Configuration . . . . . . . . . . . . . . . . . 123
7.4.4.5.4 Service Signature Characteristic . . . . . . . . . . . . . . . . . . . 123
7.4.4.6 Characteristic Metadata Descriptors . . . . . . . . . . . . . . . . . . . . . . 123
7.4.4.6.1 HAP Characteristic Properties . . . . . . . . . . . . . . . . . . . . 124
7.4.4.6.2 Characteristic User Description . . . . . . . . . . . . . . . . . . . 124
7.4.4.6.3 Characteristic Presentation Format . . . . . . . . . . . . . . . . . 124
7.4.4.6.4 Minimum and Maximum Length Descriptor . . . . . . . . . . . . . 125
7.4.4.6.5 Step Value Descriptor . . . . . . . . . . . . . . . . . . . . . . . . 125
7.4.5 Additional HAP Characteristic Requirements . . . . . . . . . . . . . . . . . . . . . . . . 126
7.4.5.1 Characteristic Format Types . . . . . . . . . . . . . . . . . . . . . . . . . . 126
7.4.5.2 Characteristic with Additional Authorization Data . . . . . . . . . . . . . . . . 126
7.4.5.3 Valid Values Descriptor . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 127
7.4.5.4 Valid Values Range Descriptor . . . . . . . . . . . . . . . . . . . . . . . . . 127
7.4.6 HAP Notifications . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 127
7.4.6.1 Connected Events . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 128
7.4.6.2 Broadcasted Events . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 128
7.4.6.3 Disconnected Events . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 128
7.4.7 Security . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 129
7.4.7.1 Pairing . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 129
7.4.7.2 Session Security . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 129
7.4.7.3 Broadcast Encryption Key Generation . . . . . . . . . . . . . . . . . . . . . 130
7.4.7.4 Broadcast Encryption Key expiration and refresh . . . . . . . . . . . . . . . . 130
7.4.7.5 Securing HAP PDUs . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 131
7.4.8 Firmware Update Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 131
7.5 Testing Bluetooth LE Accessories . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 131


**8** **Apple-defined Services** **134**
8.1 Accessory Information . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 134
8.2 Air Purifier . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 134
8.3 Air Quality Sensor . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 135
8.4 Audio Stream Management . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 136
8.5 Battery Service . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 136
8.6 Camera RTP Stream Management . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 137
8.7 Carbon Dioxide Sensor . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 137
8.8 Carbon Monoxide Sensor . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 138
8.9 Contact Sensor . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 138
8.10 Data Stream Transport Management . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 139
8.11 Door . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 139
8.12 Doorbell . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 140
8.13 Fan . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 140


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


7


CONTENTS


8.14 Faucet . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 141
8.15 Filter Maintenance . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 142
8.16 Garage Door Opener . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 142
8.17 HAP Protocol Information . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 142
8.18 Heater Cooler . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 143
8.19 Humidifier Dehumidifier . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 144
8.20 Humidity Sensor . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 145
8.21 Irrigation System . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 145
8.22 Leak Sensor . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 146
8.23 Light Bulb . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 147
8.24 Light Sensor . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 147
8.25 Lock Management . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 148
8.26 Lock Mechanism . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 148
8.27 Microphone . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 149
8.28 Motion Sensor . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 149
8.29 Occupancy Sensor . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 150
8.30 Outlet . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 150
8.31 Security System . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 150
8.32 Service Label . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 151
8.33 Siri . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 151
8.34 Slat . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 151
8.35 Smoke Sensor . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 152
8.36 Speaker . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 152
8.37 Stateless Programmable Switch . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 153
8.38 Switch . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 153
8.39 Target Control . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 154
8.40 Target Control Management . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 154
8.41 Temperature Sensor . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 155
8.42 Thermostat . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 155
8.43 Valve . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 155
8.44 Window . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 156
8.45 Window Covering . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 157


**9** **Apple-defined Characteristics** **158**
9.1 Overview . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 158
9.1.1 Overriding Properties . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 158
9.2 Accessory Flags . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 158
9.3 Active . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 159
9.4 Active Identifier . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 159
9.5 Administrator Only Access . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 160
9.6 Audio Feedback . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 160
9.7 Air Particulate Density . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 160
9.8 Air Particulate Size . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 161
9.9 Air Quality . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 161
9.10 Battery Level . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 162
9.11 Brightness . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 162
9.12 Button Event . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 163
9.13 Carbon Monoxide Level . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 164


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


8


CONTENTS


9.14 Carbon Monoxide Peak Level . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 164
9.15 Carbon Dioxide Detected . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 164
9.16 Carbon Dioxide Level . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 165
9.17 Carbon Dioxide Peak Level . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 165
9.18 Carbon Monoxide Detected . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 166
9.19 Charging State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 166
9.20 Cooling Threshold Temperature . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 167
9.21 Color Temperature . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 167
9.22 Contact Sensor State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 168
9.23 Current Ambient Light Level . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 168
9.24 Current Horizontal Tilt Angle . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 169
9.25 Current Air Purifier State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 169
9.26 Current Slat State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 170
9.27 Current Position . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 170
9.28 Current Vertical Tilt Angle . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 171
9.29 Current Humidifier Dehumidifier State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 171
9.30 Current Door State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 172
9.31 Current Fan State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 173
9.32 Current Heating Cooling State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 173
9.33 Current Heater Cooler State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 174
9.34 Current Relative Humidity . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 174
9.35 Current Temperature . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 175
9.36 Current Tilt Angle . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 175
9.37 Digital Zoom . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 176
9.38 Filter Life Level . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 176
9.39 Filter Change Indication . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 176
9.40 Firmware Revision . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 177
9.41 Hardware Revision . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 178
9.42 Heating Threshold Temperature . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 178
9.43 Hold Position . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 179
9.44 Hue . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 179
9.45 Identify . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 180
9.46 Image Rotation . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 180
9.47 Image Mirroring . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 181
9.48 In Use . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 181
9.49 Is Configured . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 182
9.50 Leak Detected . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 183
9.51 Lock Control Point . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 183
9.52 Lock Current State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 183
9.53 Lock Last Known Action . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 184
9.54 Lock Management Auto Security Timeout . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 185
9.55 Lock Physical Controls . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 185
9.56 Lock Target State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 186
9.57 Logs . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 186
9.58 Manufacturer . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 187
9.59 Model . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 187
9.60 Motion Detected . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 187
9.61 Mute . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 188


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


9


CONTENTS


9.62 Name . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 188
9.63 Night Vision . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 188
9.64 Nitrogen Dioxide Density . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 189
9.65 Obstruction Detected . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 189
9.66 PM2.5 Density . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 190
9.67 Occupancy Detected . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 190
9.68 Optical Zoom . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 190
9.69 Outlet In Use . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 191
9.70 On . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 191
9.71 Ozone Density . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 191
9.72 PM10 Density . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 192
9.73 Position State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 192
9.74 Program Mode . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 193
9.75 Programmable Switch Event . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 194
9.76 Relative Humidity Dehumidifier Threshold . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 194
9.77 Relative Humidity Humidifier Threshold . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 195
9.78 Remaining Duration . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 195
9.79 Reset Filter Indication . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 196
9.80 Rotation Direction . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 196
9.81 Rotation Speed . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 197
9.82 Saturation . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 197
9.83 Security System Alarm Type . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 198
9.84 Security System Current State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 198
9.85 Security System Target State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 199
9.86 Selected Audio Stream Configuration . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 200
9.87 Serial Number . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 201
9.88 Service Label Index . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 201
9.89 Service Label Namespace . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 202
9.90 Setup Data Stream Transport . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 202
9.91 Selected RTP Stream Configuration . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 204
9.92 Setup Endpoints . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 208
9.93 Siri Input Type . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 210
9.94 Slat Type . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 211
9.95 Smoke Detected . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 211
9.96 Status Active . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 212
9.97 Status Fault . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 212
9.98 Status Jammed . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 213
9.99 Status Low Battery . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 213
9.100 Status Tampered . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 214
9.101 Streaming Status . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 214
9.102 Supported Audio Stream Configuration . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 215
9.103 Supported Data Stream Transport Configuration . . . . . . . . . . . . . . . . . . . . . . . . . . 217
9.104 Supported RTP Configuration . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 218
9.105 Supported Video Stream Configuration . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 219
9.106 Sulphur Dioxide Density . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 221
9.107 Swing Mode . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 221
9.108 Target Air Purifier State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 221
9.109 Target Fan State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 222


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


10


CONTENTS


9.110 Target Tilt Angle . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 222
9.111 Target Heater Cooler State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 223
9.112 Set Duration . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 223
9.113 Target Control Supported Configuration . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 224
9.114 Target Control List . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 225
9.115 Target Horizontal Tilt Angle . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 227
9.116 Target Humidifier Dehumidifier State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 228
9.117 Target Position . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 229
9.118 Target Door State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 229
9.119 Target Heating Cooling State . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 230
9.120 Target Relative Humidity . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 231
9.121 Target Temperature . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 231
9.122 Temperature Display Units . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 231
9.123 Target Vertical Tilt Angle . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 232
9.124 Valve Type . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 232
9.125 Version . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 233
9.126 VOC Density . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 233
9.127 Volume . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 234
9.128 Water Level . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 234


**10 Apple-defined Profiles** **236**
10.1 Overview . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 236
10.2 Lock . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 236
10.2.1 Lock Mechanism Service . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 236
10.2.2 Lock Management Service . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 236
10.2.2.1 Control Point Characteristic Commands . . . . . . . . . . . . . . . . . . . . 236
10.2.2.2 Version Characteristic . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 237
10.2.2.3 Logs Characteristic Response Format . . . . . . . . . . . . . . . . . . . . . 237


**11** **IP Cameras** **238**
11.1 Overview . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 238
11.2 Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 238
11.2.1 Streaming Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 238
11.2.2 Optional Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 238
11.3 Service Definitions . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 239
11.3.1 IP Camera . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 239
11.3.2 Video Doorbell Profile . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 239
11.4 RTP Configuration . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 239
11.4.1 RTCP Based Feedback . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 239
11.4.2 RTP Extension for Coordination of Video Orientation . . . . . . . . . . . . . . . . . . . . 241
11.4.3 Reconfiguring a Streaming Session . . . . . . . . . . . . . . . . . . . . . . . . . . . . 242
11.5 Image Snapshot . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 242
11.6 IP Camera Streaming Procedure . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 243
11.7 Multiple Camera RTP Stream Management . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 245
11.8 Media Codecs . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 245
11.8.1 Mandatory Video RTP Service Settings . . . . . . . . . . . . . . . . . . . . . . . . . . 245
11.8.2 Mandatory Audio RTP service settings . . . . . . . . . . . . . . . . . . . . . . . . . . . 246
11.8.3 Mandatory RTP Profile . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 246


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


11


CONTENTS


11.9 Media Transport . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 246


**12 Remotes for Apple TV** **247**
12.1 Button Control Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 247
12.2 Siri Control Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 247
12.2.1 Packet Formats . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 247
12.2.1.1 Start . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 247
12.2.1.2 Binary Data . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 248
12.2.1.3 Acknowledgement . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 249
12.2.1.4 Close . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 250
12.2.1.5 Target Control Identifier . . . . . . . . . . . . . . . . . . . . . . . . . . . . 250
12.3 Additional Security Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 251


**13 Accessory Categories** **252**


**14 Appendix** **254**
14.1 TLVs . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 254
14.1.1 TLV Rules . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 254
14.1.2 TLV Examples . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 255


**15 Document Revision History** **257**


**Copyright and Notices** **259**


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


12


#### **List of Figures**

7-1 HAP Characteristic Signature Read Procedure . . . . . . . . . . . . . . . . . . . . . . . . . . . 100
7-2 HAP Characteristic Write Procedure . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 101
7-3 HAP Characteristic Read Procedure . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 102
7-4 HAP Characteristic Timed Write Procedure (1) . . . . . . . . . . . . . . . . . . . . . . . . . . . 103
7-5 HAP Characteristic Timed Write Procedure (2) . . . . . . . . . . . . . . . . . . . . . . . . . . . 104
7-6 HAP Characteristic Write-with-Response Pair Setup Procedure (1) . . . . . . . . . . . . . . . . . 105
7-7 HAP Characteristic Write-with-Response Pair Setup Procedure (2) . . . . . . . . . . . . . . . . . 106
7-8 HAP Characteristic Write-with-Response Pair Verify Procedure . . . . . . . . . . . . . . . . . . 107
7-9 HAP Fragmented Writes . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 108
7-10 HAP Fragmented Read . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 109
7-11 Pair Resume Procedure(1) . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 112
7-12 Pair Resume Procedure(2) . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 113


11-1 IP Camera - PLI Handling . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 241
11-2 IP Camera Streaming Procedure . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 244


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


13


#### **List of Tables**

2-1 Additional HomeKit Accessory Protocol Requirements . . . . . . . . . . . . . . . . . . . . . . . 24


5-1 HTTP Status Codes . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 48
5-2 HTTP URLs . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 49
5-3 Methods . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 49
5-4 Pairing Feature Flags . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 49
5-5 Error Codes . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 50
5-6 TLV Values . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 51
5-7 Pairing Type Flags . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 51


6-1 Properties of HAP accessory objects in JSON . . . . . . . . . . . . . . . . . . . . . . . . . . . 53
6-2 Properties of Service Objects in JSON . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 54
6-3 Properties of Characteristic Objects in JSON . . . . . . . . . . . . . . . . . . . . . . . . . . . 54
6-4 Characteristic Permissions . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 56
6-5 Characteristic Value Formats . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 57
6-6 Characteristic Units . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 57
6-7 _`_hap._tcp`_ Bonjour TXT Record Keys . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 58
6-8 Bonjour TXT Status Flags . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 58
6-9 Derived Session Key Usage . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 59
6-10 HAP Status Code Property . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 67
6-11 HAP Status Codes . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 67
6-12 Properties of Characteristic Write Objects in JSON . . . . . . . . . . . . . . . . . . . . . . . . . 68
6-13 HAP GET Request URL Parameters . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 74
6-14 HTTP URLs . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 80
6-15 Properties of Event Messages . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 82
6-16 Properties of Request Messages . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 83
6-17 Properties of Response Messages . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 83
6-18 Properties of Data Format Table 1 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 85
6-19 Properties of Data Format Table 2 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 86


7-1 HAP PDU Format . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 89
7-2 HAP PDU Header - Control Field . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 89
7-3 Control Field Bit 7 Values . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 90
7-4 Control Field Bit 4 Values . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 90
7-5 Control Field Bit 1-3 Values . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 90
7-6 Control Field Bit 0 Values . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 90
7-7 HAP-BLE Request Format . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 90
7-8 HAP Opcode Description . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 91
7-9 HAP Response Format . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 91


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


14


LIST OF TABLES


7-10 Additional Parameter Types Description . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 92
7-11 HAP PDU Fragmentation Scheme . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 93
7-12 HAP-Characteristic-Signature-Read-Request . . . . . . . . . . . . . . . . . . . . . . . . . . . 93
7-13 HAP-Characteristic-Signature-Read-Response 1 . . . . . . . . . . . . . . . . . . . . . . . . . . 93
7-14 HAP-Characteristic-Signature-Read-Response 2 . . . . . . . . . . . . . . . . . . . . . . . . . 94
7-15 HAP-Characteristic-Signature-Read-Response (with Valid Values) 1 . . . . . . . . . . . . . . . . 94
7-16 HAP-Characteristic-Signature-Read-Response (with Valid Values) 2 . . . . . . . . . . . . . . . . 94
7-17 HAP-Characteristic-Write-Request . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 94
7-18 HAP-Characteristic-Write-Response . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 95
7-19 HAP-Characteristic-Read-Request . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 95
7-20 HAP-Characteristic-Read-Response . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 95
7-21 HAP-Characteristic-Timed-Write-Request . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 95
7-22 HAP-Characteristic-Timed-Write-Response . . . . . . . . . . . . . . . . . . . . . . . . . . . . 96
7-23 HAP-Characteristic-Execute-Write-Request . . . . . . . . . . . . . . . . . . . . . . . . . . . . 96
7-24 HAP-Characteristic-Execute-Write-Response . . . . . . . . . . . . . . . . . . . . . . . . . . . 96
7-25 HAP-Service-Signature-Read-Request . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 96
7-26 HAP-Service-Signature-Read-Response . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 97
7-27 HAP-Characteristic-Configuration-Request . . . . . . . . . . . . . . . . . . . . . . . . . . . . 97
7-28 Characteristic configuration parameter types . . . . . . . . . . . . . . . . . . . . . . . . . . . . 97
7-29 Characteristic configuration properties . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 97
7-30 Broadcast Interval . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 98
7-31 HAP-Characteristic-Configuration-Response . . . . . . . . . . . . . . . . . . . . . . . . . . . 98
7-32 Protocol Configuration Request Types . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 98
7-33 HAP-Protocol-Configuration-Request . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 98
7-34 Protocol Configuration Parameter Types . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 99
7-35 HAP-Protocol-Configuration-Response 1 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 99
7-36 HAP-Protocol-Configuration-Response 2 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 99
7-37 HAP Status Codes Description . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 110
7-38 Defines Description . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 111
7-39 Flags Description . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 117
7-40 Manufacturer Specific Data . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 118
7-41 Manufacturer Specific Data - continued . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 118
7-42 SubType / Length . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 119
7-43 HAP Pairing Status Flag . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 119
7-44 Local Name . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 119
7-45 Flags Description . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 120
7-46 Manufacturer Specific Data . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 120
7-47 Manufacturer Specific Data - continued (Encrypted and Authenticated Payload) . . . . . . . . . . 121
7-48 SubType / Length . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 121
7-49 HAP Service Properties . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 122
7-50 HAP Characteristic Description . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 124
7-51 HAP Format to BT SIG Format mapping . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 125
7-52 HAP Unit to BT SIG Unit mapping . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 125
7-53 Bluetooth LE Characteristic Descriptors . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 126
7-54 Derived Key Usage . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 130


9-1 Button Event TLV8 Definition . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 163
9-2 Selected Audio Input Stream Configuration TLV8 Definition . . . . . . . . . . . . . . . . . . . . . 200


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


15


LIST OF TABLES


9-3 Selected Audio Stream Configuration TLV TLV8 Definition . . . . . . . . . . . . . . . . . . . . . 201
9-4 Setup Data Steam Session TLV8 Definition . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 203
9-5 Setup Data Stream Write Response TLV8 Definition . . . . . . . . . . . . . . . . . . . . . . . . 203
9-6 Setup Data Stream Transport Configuration 3 TLV8 Definition . . . . . . . . . . . . . . . . . . . 203
9-7 Selected RTP Stream Configuration . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 204
9-8 Session Control Command . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 205
9-9 Selected Video Parameters . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 205
9-10 Video RTP Parameters . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 206
9-11 Selected Audio Parameters . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 207
9-12 Audio RTP Parameters . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 207
9-13 Setup Endpoints . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 208
9-14 Controller Address . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 208
9-15 SRTP Crypto Suite . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 209
9-16 Read Response . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 210
9-17 Streaming Status . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 215
9-18 Supported Audio Stream Configuration . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 215
9-19 Audio Codecs . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 216
9-20 Mandatory RTP Time Values . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 216
9-21 Audio Codec Parameters . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 217
9-22 Transfer Transport Configuration TLV8 Definition . . . . . . . . . . . . . . . . . . . . . . . . . . 217
9-23 Transport Type TLV8 Definition . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 218
9-24 Supported RTP Configuration . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 218
9-25 Supported Video Stream Configuration . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 219
9-26 Video Codec Configuration . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 219
9-27 Video Codec Parameters . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 220
9-28 Video Attributes . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 220
9-29 Target Control Commands TLV8 Definition . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 224
9-30 Supported Button Configuration Format TLV8 Definition . . . . . . . . . . . . . . . . . . . . . . 225
9-31 Target Control List TLV8 Definition . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 226
9-32 Target Configuration TLV8 Definition . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 226
9-33 Target Category Enumerations . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 226
9-34 Button Configuration TLV8 Definition . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 227


10-1 Lock Control Point Characteristic Commands TLV8 Definition . . . . . . . . . . . . . . . . . . . 237
10-2 Logs Characteristic Response Format TLV8 Definition . . . . . . . . . . . . . . . . . . . . . . . 237


11-1 Video Doorbell Secondary Services . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 239
11-2 Video Resolutions . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 245


12-1 Request Properties . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 248
12-2 Response Properties . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 248
12-3 Event Properties . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 248
12-4 Packet Dictionary . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 249
12-5 Siri Audio Data . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 249
12-6 Acknowledgement Event . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 249
12-7 Close Event . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 250
12-8 Target Control Event . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 250


13-1 Accessory Categories . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 252


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


16


LIST OF TABLES


14-1 TLV8 Structure . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 254
14-2 TLV8 Value Formats . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 254


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


17


### 1 Introduction

NOTICE OF PROPRIETARY PROPERTY: THIS DOCUMENT AND THE INFORMATION CONTAINED HEREIN IS THE
PROPRIETARY PROPERTY OF APPLE INC.ACCESS TO AND USE OF THIS DOCUMENT AND THE INFORMATION
CONTAINED HEREIN IS GOVERNED BY THE TERMS OF THE LIMITED LICENSE TO HOMEKIT ACCESSORY PROTOCOL SPECIFICATION (NON-COMMERCIAL VERSION) (THE “AGREEMENT”).


THIS DOCUMENT IS INTENDED TO BE USED FOR INFORMATIONAL PURPOSES SOLELY TO CREATE HARDWARE
ACCESSORIES THAT COMMUNICATE WITH APPLE PRODUCTS USING THE HOMEKIT ACCESSORY PROTOCOL,
FOR THE RECEIVING PARTYʼS OWN PERSONAL, NON-COMMERCIAL USE AND ENJOYMENT, AND NOT FOR DISTRIBUTION OR SALE. ANY OTHER USE OF THIS DOCUMENT IS STRICTLY PROHIBITED. IF YOU HAVE NOT AGREED
TO BE BOUND BY THE TERMS OF THE AGREEMENT, YOU MAY NOT ACCESS OR USE THIS DOCUMENT.

##### 1.1 Purpose of This Specification


This document describes how to create HomeKit accessories that communicate with Apple products using the HomeKit Accessory Protocol for non-commercial purposes. Companies that intend to develop or manufacture a HomeKit[enabled accessory that will be distributed or sold must be enrolled in the MFi Program.](https://developer.apple.com/programs/mfi/)

##### 1.2 Requirements, Recommendations, and Permissions


The use of the words _must_, _must not_, _required_, _shall_, _shall not_, _should_, _should not_, _recommended_, _not recommended_,
_may_, _optional_, and _deprecated_ in a statement have the following meanings:


   - _must_, _shall_, or _required_ means the statement is an absolute requirement.


   - _must not_, _shall not_ or _prohibited_ means the statement is an absolute prohibition.


   - _should_ or _recommended_ means the full implications must be understood before choosing a different course.


   - _should not_ or _not recommended_ means the full implications must be understood before choosing this course.


   - _may_ or _optional_ means the statement is truly optional, and its presence or absence cannot be assumed.


   - _deprecated_ means the statement is provided for historical purposes only and is equivalent to ʼmust notʼ.


The absence of requirements, recommendations, or permissions for a specific accessory design in this specification
must not be interpreted as implied approval of that design.

##### 1.3 Terminology


1.3.1 Accessory, Device, and Product


Throughout this specification:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


18


1. Introduction


  - The term _device_ or _controller_ is used to refer to an Apple iPod, iPhone, iPad or Watch (typically running iOS
or watchOS, Appleʼs mobile operating system).


  - The term _accessory_ is used to refer to any product intended to interface with a device via the means described
in this specification.


  - The term _product_ is used to refer generically to either a Mac (Apple computers that run macOS) or an aforementioned _device_ .


1.3.2 Component


An accessory is defined as a collection of functional units called _components_ . Examples of a component include, but
are not limited to, the following:


  - Data transport


  - Power source


  - Human Interface Device (HID) control set


1.3.3 Feature


All accessories must support one or more accessory interface _features_ . Each feature may have associated accessory design requirements and recommendations; an accessory must comply with all feature-specific requirements to
properly support the feature. Some features require other features to be implemented.


Accessory design must take into account the possibility that an Apple device may not support all of the accessoryʼs
implemented features and react appropriately.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


19


### 2 Core Concepts

The HomeKit Accessory Specification defines how an Apple device communicates with an accessory using HomeKit
Accessory Protocol, or HAP. For example, an iOS device uses HAP to discover, explore, and interact with HomeKit
accessories such as lights, door locks, and garage door openers.

##### 2.1 Transports


HomeKit Accessory Protocol supports two transports: Bluetooth LE and IP. HomeKit accessories may support either
transport or both transports. The transport-specific protocols are covered in ”6 HomeKit Accessory Protocol for IP
Accessories” (page 52) and ”7 HomeKit Accessory Protocol for Bluetooth LE Accessories” (page 88).

##### 2.2 Security


HomeKit Accessory Protocol sessions are end-to-end encrypted and mutually authenticated. Sessions also feature
perfect forward secrecy, meaning that a new, unique key is generated for every session. The foundation of this security
is provided by Pairing.


2.2.1 Pairing


Pairing establishes a cryptographic relationship between an iOS device and an accessory. There are two components
to Pairing: Pair Setup and Pair Verify.


2.2.1.1 Pair Setup


Pair Setup is a one-time operation that creates a valid pairing between an iOS device and an accessory by securely
exchanging public keys with an iOS device and an accessory. Pair Setup requires the customer to enter an eight-digit
setup code on their iOS device. The setup code is provided by the accessory via a label or display.


2.2.1.2 Pair Verify


Pair Verify is performed for every HomeKit Accessory Protocol session. Pair Verify verifies the pairing between an iOS
device and an accessory and establishes an ephemeral shared secret used to secure the HomeKit Accessory Protocol
session.


2.2.2 Session Keys


Encryption and authentication keys are derived from the ephemeral shared secret established during Pair Verify.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


20


2. Core Concepts

##### 2.3 Attributes


HomeKit Accessory Protocol uses two types of attributes, services and characteristics, to model the capabilities of
an accessory.


2.3.1 Accessories


Accessories are comprised of services and characteristics. An example of an accessory is a ceiling fan with a light
and a mister that sprays cool water.


2.3.2 Services


Services group functionality in order to provide context. In the aforementioned example accessory there are three
services: a fan service to interact with the ceiling fan, a light service to interact with the light, and a mister service to
interact with the spray mister.


2.3.2.1 Service Naming


Not all services provide user-visible or user-interactive functionality. Services which provide either user-visible or
user-interactive functionality must include the Name characteristic, see ”9.62 Name” (page 188); all other services
must not include this characteristic. This convention is used by iOS controllers to determine which services to display
to users.


In the aforementioned ceiling fan example, the fan, light, and mister services would all include a Name characteristic. There may be an additional service providing firmware update capabilities. The characteristics contained in this
service are not meant to be user-visible or user-interactive, thus this service would not contain a Name characteristic.


Note that the Accessory Information service, see ”8.1 Accessory Information” (page 134), is an exception and always
includes the Name characteristic even though it is not typically user-visible or user-interactive.


2.3.2.2 Extending Services


To maintain backward compatibility with earlier clients, any characteristics added in later versions of a service must
be optional. Later versions of a service must not change behaviors defined in previous versions of the service.


2.3.2.3 Primary Service


Accessories should list one of its services as the primary service. The primary service must match the primary function
of the accessory and must also match with the accessory category. An accessory must expose only one primary
service from its list of available services.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


21


2. Core Concepts


2.3.2.4 Hidden Service


Accessories may specify the services that are to be hidden from users by a generic HomeKit application. Accessories
may expose several services that could be used to configure the accessory or to update firmware on the accessory,
these services should be marked as hidden. When all characteristics in a service are marked hidden then the service
must also be marked as hidden.


2.3.2.5 Linked Service


Linked services allows accessories to specify logical relationship between services. A service can link to one or more
services. A service must not link to itself. Service links have context and meaning only to the first level of services that
it links to. For example if Service A links to Service B, and service B links to Service C, this does not imply any relation
between Service A to Service C. If Service A also relates to Service C then Service Aʼs linked services must include
both Service B and Service C. Linked services allows applications to display logically grouped accessory controls in
the UI.


2.3.3 Characteristics


A characteristic is a feature that represents data or an associated behavior of a service. The characteristic is defined
by a universally unique type, and has additional properties that determine how the value of the characteristic can be
accessed.


  - The properties of _`perms`_ and _`ev`_, for example, indicate read/write/notify permissions, and event notifications.


   - The characteristic may also have other properties that further describe the characteristic. Properties like

_`format`_ describe the format of the characteristicʼs value such as int or string, description contains a
description string, and _`minValue`_, _`maxValue`_, and _`minStep`_ refer to minimum, maximum, and step limits that
also apply to the characteristicʼs value.


  - For example, the ”8.23 Light Bulb” (page 147) service contains a ”9.11 Brightness” (page 162) characteristic
of type _`public.hap.characteristic.brightness`_ with permissions of paired read ( _`pr`_ ) and paired
write ( _`pw`_ ). The ʼ ”9.11 Brightness” (page 162) characteristic may have additional properties describing the
value. For example, a _`format`_ property can indicate that the value is an int number, and a _`unit`_ property can
indicate that the value is in percentage. Furthermore, other properties can be used to indicate a minimum
value of 0, maximum value of 100, and step value of 1 via the _`minValue`_, _`maxValue`_, and minStep properties.


A characteristic may apply to many different services. In the aforementioned example accessory, the light bulb service
may have the following characteristics:


   - ”9.70 On” (page 191): This characteristic is a Boolean value that represents the power state of the light: a _`true`_
value indicates the light is turned on and a _`false`_ value indicates the light is turned off.


   - ”9.11 Brightness” (page 162): This characteristic is an Int value that describes the perceived brightness of the
light bulb expressed as a percentage of the maximum level of supported brightness.


   - ”9.44 Hue” (page 179): This characteristic identifies the hue or color of the light bulb.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


22


2. Core Concepts


   - ”9.62 Name” (page 188): This characteristic is a string value that identifies the name of light bulb.


  - ”9.82 Saturation” (page 197): This characteristic describes the color saturation level of the light bulb as a
percentage of the maximum color saturation level.


  - ”9.21 Color Temperature” (page 167): This characteristic describes color temperature which is represented in
reciprocal megaKelvin (MK [-1] ) or mirek scale. ( _`M = 1,000,000 / K`_ where M is the desired mirek value and
K is temperature in Kelvin).


A ”8.38 Switch” (page 153) service may have the following characteristics:


  - ”9.70 On” (page 191): This characteristic is a Boolean value that represents the power state of the switch a

_`true`_ value indicates the switch is turned on and a _`false`_ value indicates the switch is turned off.


   - ”9.62 Name” (page 188): This characteristic is a string value that identifies the name of the switch.


Note that both the ”9.70 On” (page 191) and ”9.62 Name” (page 188) characteristics may define the light bulb and
switch services. The protocol-level interaction between an iOS device and an accessory is the same, but the service
provides the context for the characteristic.


2.3.3.1 Valid Characteristic Values


Accessory characteristics that support only a sub-set of the Apple-defined enum values can indicate the supported
values as part of the characteristicʼs metadata.


2.3.3.2 Additional Authorization Data


Certain types of characteristics may support additional authorization data for write requests by default. Additional
authorization data is controller-provided data that the accessory may use to validate that the controller is authorized
to perform a requested operation. The contents of the authorization data are manufacturer specific. The additional
authorization data is provided by the accessory app (an iOS app provided by the accessory manufacturer to control
or configure the accessory) to iOS and stored by iOS on the controller. The additional authorization data must not
be unique per write request as the controller will not construct or receive unique authorization data for each request.
Additional authorization data may change periodically, e.g. once per month, or when user permissions change.


The characteristic and service combination that support additional authorization data by default are ”9.118 Target
Door State” (page 229) in the ”8.16 Garage Door Opener” (page 142) and the ”9.56 Lock Target State” (page 186) in
the ”8.16 Garage Door Opener” (page 142) and ”8.26 Lock Mechanism” (page 148).


For example, a HomeKit accessory implementing an exterior lock, see ”8.26 Lock Mechanism” (page 148), may wish
to allow control of the lock by all primary users of the home at any time. This user group has additional authorization
data ʼAʼ. Another group of secondary users are only allowed control of the lock during specific times of the day, for
instance 9�00 AM to 6�00 PM; this user group has additional authorization data ʼBʼ. When a primary userʼs controller
writes to the Target Lock State, ”9.56 Lock Target State” (page 186), the controller will include the additional authorization data ʼAʼ along with the write request. The lock can verify that the controller is authorized to perform the write
operation at any time of the day based on the inclusion of additional authorization data ʼAʼ. However, if, for instance, a
secondary userʼs controller attempts to write to the Target Lock State at 10�00 PM, this write request will include the
additional authorization data ʼBʼ, and the accessory could then reject the write as not authorized at that time based on
the inclusion of additional authorization data ʼBʼ.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


23


2. Core Concepts


2.3.4 Additional HomeKit Accessory Protocol Requirements


The following is a summary of additional HomeKit Accessory Protocol requirements


**Table 2-1:** Additional HomeKit Accessory Protocol Requirements

|Feature|Requirement|Description|
|---|---|---|
|Primary Service|Optional|Accessories may choose to indicate a primary service|
|Linked Service|Optional||
|Hidden Service|Conditional|If the accessory exposes custom services for proprietary con-<br>trols on the accessory then it must include a Hidden service|
|Valid Values / Valid Values range|Conditional|When a characteristic supports only a subset of the Apple de-<br>fined enum values then it must include Valid Values / Valid Val-<br>ues Range|
|Accessory Flags|Conditional|If accessory requires additional setup or configuration using<br>the accessory manufacturerʼs app then it must include Acces-<br>sory Flags|


##### 2.4 Profiles


Profiles define the appropriate services and characteristics to be used to provide consistent behavior. For example, a
Light profile uses the ”8.23 Light Bulb” (page 147) that requires a ”9.70 On” (page 191) characteristic. The Light profile
takes services a step further by mandating that a light must stop illuminating entirely when the ”9.70 On” (page 191)
is set to a value of _`false`_ .

##### 2.5 Roles


2.5.1 HAP Client


  - Always the controller.


  - Send requests and receive responses from HAP accessory servers.


  - Register for and receive notifications from HAP accessory servers.


2.5.2 HAP Accessory Server


An HAP accessory server is a device that supports HomeKit Accessory Protocol and exposes a collection of accessories to the HAP controller(s). An HAP accessory server represents one endpoint of the pairing relationship established with HAP Pairing, as described in ”5 Pairing” (page 31) and exposes at least one HAP accessory object.


  - Always the accessory.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


24


2. Core Concepts


  - Expose attributes that can be accessed by HAP clients.


  - Accept incoming requests from clients and send responses.


   - Send notifications to registered clients.


2.5.3 HAP Accessory Objects


An HAP accessory object represents a physical accessory on an HAP accessory server. For example, a thermostat
would expose a single HAP accessory object that represents the user-addressable functionality of the thermostat.


2.5.3.1 Required Services


An HAP accessory object must include at least one service, public.hap.service.accessory-information, as defined in
the ”10 Apple-defined Profiles” (page 236).


2.5.3.2 Bridges


A bridge is a special type of HAP accessory server that bridges HomeKit Accessory Protocol and different RF/transport
protocols, such as Zigbee or Z-Wave. A bridge must expose all the user-addressable functionality supported by its
connected bridged endpoints as HAP accessory objects to the HAP controllers. A bridge must ensure that the instance
ID assigned to the HAP accessory objects exposed on behalf of its connected bridged endpoints do not change for
the lifetime of the server/client pairing.


For example, a bridge that bridges three lights would expose four HAP accessory objects: one HAP accessory object
that represents the bridge itself that may include a firmware update service, and three additional HAP accessory
objects that each contain a Light Bulb service.


A bridge must not expose more than 150 HAP accessory objects.


Any accessories, regardless of transport, that enable physical access to the home, such as door locks, must not
be bridged. Accessories that support IP transports, such as Wi-Fi, must not be bridged. Accessories that support
Bluetooth LE that can be controlled, such as a light bulb, must not be bridged. Accessories that support Bluetooth LE
that only provide data, such as a temperature sensor, and accessories that support other transports, such as a ZigBee
light bulb or a proprietary RF sensor, may be bridged.


2.5.3.3 Primary HAP Accessory Object


The HAP accessory object with an instance ID of 1 is considered the primary HAP accessory object. For bridges, this
must be the bridge itself.


2.5.3.4 Colocation


The services contained within an HAP accessory object must be collocated. For example, a fan with a light on it would
expose single HAP accessory object with three services: the Required Accessory Information service, a Fan service,
and a Light Bulb service. Conversely, a bridge that bridges two independent lights that may be in different physical
locations must expose an HAP accessory object for each independent light.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


25


2. Core Concepts

##### 2.6 Accessory Attribute Database


The accessory attribute database is a list of HAP accessory objects, Service objects, and Characteristic objects.


2.6.1 Instance IDs


instance IDs are numbers with a range of [1, 18446744073709551615] for IP accessories (see ”7.4.4.2 Instance IDs”
(page 122) for BLE accessories). These numbers are used to uniquely identify HAP accessory objects within an HAP
accessory server, or uniquely identify services, and characteristics within an HAP accessory object. The instance ID
for each object must be unique for the lifetime of the server/client pairing.


2.6.1.1 Accessory Instance IDs


Accessory instance IDs, _`aid`_, are assigned from the same number pool that is global across entire HAP accessory
server. For example, if the first Accessory object has an instance ID of “1”, then no other Accessory object can have
an instance ID of “1” within the Accessory Server.


2.6.1.2 Service and Characteristic Instance IDs


Service and Characteristic instance IDs, _`iid`_, are assigned from the same number pool that is unique within each Accessory object. For example, if the first Service object has an instance ID of “1”, then no other Service or Characteristic
objects can have an instance ID of “1” within the parent Accessory object. The Accessory Information service must
have a service instance ID of 1.


After a firmware update, services and characteristics types that remain unchanged must retain their previous instance
IDs, newly added services and characteristics must not reuse instance IDs from services and characteristics that were
removed in the firmware update.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


26


### 3 Requirements

##### 3.1 Overview

Accessories that support HomeKit Accessory Protocol (HAP) must conform to the following requirements along with
any feature specific requirements contained in their respective chapters.

##### 3.2 General Requirements


An accessory that supports HAP:


  - must support accessory setup as defined in ”4 Accessory Setup” (page 29).


  - may expose other interfaces, such as a public API.

##### 3.3 Wi-Fi Requirements


  - Accessories which use Wi-Fi for HAP communication must be on the same Wi-Fi network as the iOS device
prior to HomeKit pairing.


  - The method to join the accessory to the Wi-Fi network will vary depending on the development platform you
are using.

##### 3.4 Firmware Updates


  - Accessories must not allow a firmware image to be downgraded after a successful firmware update.


  - Accessories must increment the _`config number`_ (CN). For IP accessories, see ”6.4 Discovery” (page 57)
and for Bluetooth accessories see ”7.4.2.1 HAP BLE Regular Advertisement Format” (page 118) after a firmware
update.


  - Accessories must maintain the instance ids for services and characteristics that remain unchanged after a
firmware update.


  - Accessories must not reuse an instance id from a service or characteristics that was removed by the current
firmware update.

##### 3.5 Coalescing Requirements


An accessory that supports multiple transports (for example, HomeKit Accessory Protocol for IP and HomeKit Accessory Protocol for Bluetooth LE) must ensure that the following information is same across all transports:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


27


3. Requirements


- The set of accessories and the accessory instance IDs of each of the accessories.


- The set of services and the service instance IDs of each of the services within an accessory.


- The set of HAP characteristics and the HAP characteristic instance IDs of each of the characteristics within a
service.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


28


### 4 Accessory Setup

##### 4.1 Overview

This chapter describes how the HomeKit setup payload information is generated, stored, displayed and delivered by
the accessory to the controller for pairing purposes.

##### 4.2 Setup Payload


4.2.1 Setup Code


The setup code must conform to the format _`XXXXXXXX`_ where each _`X`_ is a 0-9 digit. For example, _`10148005`_ . For the
purposes of generating accessory SRP verifier (see ”5.6 Pair Setup” (page 34)), the setup code must be formatted
as _`XXX-XX-XXX`_ (including dashes). In this example, the format of setup code used by the SRP verifier must be

_`101-48-005`_ .


4.2.1.1 Generation of Setup Code


If an accessory generates a random setup code, it must conform to the following rules:


  - The accessory must generate a new setup code each time it is needed.


  - The accessory must generate setup codes from a cryptographically secure random number generator.


  - Setup codes must not be derived from public information, such as a serial number, manufacturer date, MAC
address, region of origin, etc.


If an accessory cannot generate a dynamic setup code, then it must conform to the following rules:


  - A random setup code must be generated for each individual accessory.


  - The manufacturing process must use a cryptographically secure random number generator.


  - The accessory must be manufactured with an SRP verifier for the setup code rather than the raw setup code.


  - Setup codes must not be derived from public information, such as a serial number, date of manufacture, MAC
address, region of origin, etc.


4.2.1.2 Invalid Setup Codes


The following are examples of setup codes that must not be used due to their trivial, insecure nature:


  - 00000000


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


29


4. Accessory Setup




- 11111111


- 22222222


- 33333333


- 44444444


- 55555555


- 66666666


- 77777777


- 88888888


- 99999999


- 12345678


- 87654321



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


30


### 5 Pairing

##### 5.1 Overview

This chapter describes the process of cryptographically pairing devices with accessories. It has the following features:


  - Provides end-to-end security without exposing secret information to external entities.


  - Secret keys are generated on the accessory and must not leave the accessory where they are used.


   - Does not rely on link layer security (i.e. safe to run over open Wi-Fi networks).


   - Is transport neutral (e.g. can work over Wi-Fi/IP, Bluetooth, etc.).


  - Is practical to implement and is efficient even in resource-constrained accessories.


  - Keys are revocable without cooperation from the peer.

##### 5.2 Cryptographic Key Storage


Keys must be stored in a secure manner to prevent unauthorized access. Keys must not be accessible in any way from
outside the device. The recommended mechanism is to generate, store, and operate on keys only within a Secure
Element. The only operation requiring a secret key is signing and that can be performed inside the Secure Element to
minimize attacks. Pairing also requires storing the public key of each paired peer. These keys, although public, must
also be stored securely because they are used to verify pairing relationships. For example, insecure storage could
allow a pairing to be added without going through the Pair Setup procedure or deny legitimate use of a pairing. If a
device is physically reset, all cryptographic keys must be erased.

##### 5.3 Admins


Admins are pairings that have the admin bit set. Admins are exclusively authorized to add, remove, and list pairings.

##### 5.4 Device ID


This identifier of the accessory must be a unique random number generated at every factory reset and must persist
across reboots.

##### 5.5 Secure Remote Password (SRP)


5.5.1 SRP Modifications


Pairing uses Stanfordʼs Secure Remote Password protocol with the following modifications:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


31


5. Pairing


   - _`SHA-512`_ is used as the hash function, replacing _`SHA-1`_ . If the SRP reference implementation provided by
Stanford is being used then the function that generates the Session Key, _`K`_, from the Premaster Secret, _`S`_, must
be changed from Mask Generation Function 1, _`t_mgf1()`_, to the specified hash function, _`SHA-512`_ .


  - The Modulus, _`N`_, and Generator, _`g`_ [, are specified by the 3072-bit group of RFC 5054.](https://tools.ietf.org/html/rfc5054)


5.5.2 SRP Test Vectors


The following test vectors demonstrate calculation of the Verifier (v), Premaster Secret (S), and Session Key (K).

```
# Modulus (N), as specified by the 3072-bit group of RFC 5054
FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1 29024E08 8A67CC74
020BBEA6 3B139B22 514A0879 8E3404DD EF9519B3 CD3A431B 302B0A6D F25F1437
4FE1356D 6D51C245 E485B576 625E7EC6 F44C42E9 A637ED6B 0BFF5CB6 F406B7ED
EE386BFB 5A899FA5 AE9F2411 7C4B1FE6 49286651 ECE45B3D C2007CB8 A163BF05
98DA4836 1C55D39A 69163FA8 FD24CF5F 83655D23 DCA3AD96 1C62F356 208552BB
9ED52907 7096966D 670C354E 4ABC9804 F1746C08 CA18217C 32905E46 2E36CE3B
E39E772C 180E8603 9B2783A2 EC07A28F B5C55DF0 6F4C52C9 DE2BCBF6 95581718
3995497C EA956AE5 15D22618 98FA0510 15728E5A 8AAAC42D AD33170D 04507A33
A85521AB DF1CBA64 ECFB8504 58DBEF0A 8AEA7157 5D060C7D B3970F85 A6E1E4C7
ABF5AE8C DB0933D7 1E8C94E0 4A25619D CEE3D226 1AD2EE6B F12FFA06 D98A0864
D8760273 3EC86A64 521F2B18 177B200C BBE11757 7A615D6C 770988C0 BAD946E2
08E24FA0 74E5AB31 43DB5BFC E0FD108E 4B82D120 A93AD2CA FFFFFFFF FFFFFFFF

# Generator (g), as specified by the 3072-bit group of RFC 5054
05

# Username (I), as an ASCII string without quotes
”alice”

# Password (p), as an ASCII string without quotes
”password123”

# A private (a)
60975527 035CF2AD 1989806F 0407210B C81EDC04 E2762A56 AFD529DD DA2D4393

# A public (A)
FAB6F5D2 615D1E32 3512E799 1CC37443 F487DA60 4CA8C923 0FCB04E5 41DCE628
0B27CA46 80B0374F 179DC3BD C7553FE6 2459798C 701AD864 A91390A2 8C93B644
ADBF9C00 745B942B 79F9012A 21B9B787 82319D83 A1F83628 66FBD6F4 6BFC0DDB
2E1AB6E4 B45A9906 B82E37F0 5D6F97F6 A3EB6E18 2079759C 4F684783 7B62321A
C1B4FA68 641FCB4B B98DD697 A0C73641 385F4BAB 25B79358 4CC39FC8 D48D4BD8
67A9A3C1 0F8EA121 70268E34 FE3BBE6F F89998D6 0DA2F3E4 283CBEC1 393D52AF
724A5723 0C604E9F BCE583D7 613E6BFF D67596AD 121A8707 EEC46944 95703368
6A155F64 4D5C5863 B48F61BD BF19A53E AB6DAD0A 186B8C15 2E5F5D8C AD4B0EF8
AA4EA500 8834C3CD 342E5E0F 167AD045 92CD8BD2 79639398 EF9E114D FAAAB919
E14E8509 89224DDD 98576D79 385D2210 902E9F9B 1F2D86CF A47EE244 635465F7

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


32


5. Pairing


```
1058421A 0184BE51 DD10CC9D 079E6F16 04E7AA9B 7CF7883C 7D4CE12B 06EBE160
81E23F27 A231D184 32D7D1BB 55C28AE2 1FFCF005 F57528D1 5A88881B B3BBB7FE

# B private (b)
E487CB59 D31AC550 471E81F0 0F6928E0 1DDA08E9 74A004F4 9E61F5D1 05284D20

# B public (B)
40F57088 A482D4C7 733384FE 0D301FDD CA9080AD 7D4F6FDF 09A01006 C3CB6D56
2E41639A E8FA21DE 3B5DBA75 85B27558 9BDB2798 63C56280 7B2B9908 3CD1429C
DBE89E25 BFBD7E3C AD3173B2 E3C5A0B1 74DA6D53 91E6A06E 465F037A 40062548
39A56BF7 6DA84B1C 94E0AE20 8576156F E5C140A4 BA4FFC9E 38C3B07B 88845FC6
F7DDDA93 381FE0CA 6084C4CD 2D336E54 51C464CC B6EC65E7 D16E548A 273E8262
84AF2559 B6264274 215960FF F47BDD63 D3AFF064 D6137AF7 69661C9D 4FEE4738
2603C88E AA098058 1D077584 61B777E4 356DDA58 35198B51 FEEA308D 70F75450
B71675C0 8C7D8302 FD7539DD 1FF2A11C B4258AA7 0D234436 AA42B6A0 615F3F91
5D55CC3B 966B2716 B36E4D1A 06CE5E5D 2EA3BEE5 A1270E87 51DA45B6 0B997B0F
FDB0F996 2FEE4F03 BEE780BA 0A845B1D 92714217 83AE6601 A61EA2E3 42E4F2E8
BC935A40 9EAD19F2 21BD1B74 E2964DD1 9FC845F6 0EFC0933 8B60B6B2 56D8CAC8
89CCA306 CC370A0B 18C8B886 E95DA0AF 5235FEF4 393020D2 B7F30569 04759042

# Salt (s)
BEB25379 D1A8581E B5A72767 3A2441EE

# Verifier (v)
9B5E0617 01EA7AEB 39CF6E35 19655A85 3CF94C75 CAF2555E F1FAF759 BB79CB47
7014E04A 88D68FFC 05323891 D4C205B8 DE81C2F2 03D8FAD1 B24D2C10 9737F1BE
BBD71F91 2447C4A0 3C26B9FA D8EDB3E7 80778E30 2529ED1E E138CCFC 36D4BA31
3CC48B14 EA8C22A0 186B222E 655F2DF5 603FD75D F76B3B08 FF895006 9ADD03A7
54EE4AE8 8587CCE1 BFDE3679 4DBAE459 2B7B904F 442B041C B17AEBAD 1E3AEBE3
CBE99DE6 5F4BB1FA 00B0E7AF 06863DB5 3B02254E C66E781E 3B62A821 2C86BEB0
D50B5BA6 D0B478D8 C4E9BBCE C2176532 6FBD1405 8D2BBDE2 C33045F0 3873E539
48D78B79 4F0790E4 8C36AED6 E880F557 427B2FC0 6DB5E1E2 E1D7E661 AC482D18
E528D729 5EF74372 95FF1A72 D4027717 13F16876 DD050AE5 B7AD53CC B90855C9
39566483 58ADFD96 6422F524 98732D68 D1D7FBEF 10D78034 AB8DCB6F 0FCF885C
C2B2EA2C 3E6AC866 09EA058A 9DA8CC63 531DC915 414DF568 B09482DD AC1954DE
C7EB714F 6FF7D44C D5B86F6B D1158109 30637C01 D0F6013B C9740FA2 C633BA89

# Random Scrambling Parameter (u)
03AE5F3C 3FA9EFF1 A50D7DBB 8D2F60A1 EA66EA71 2D50AE97 6EE34641 A1CD0E51
C4683DA3 83E8595D 6CB56A15 D5FBC754 3E07FBDD D316217E 01A391A1 8EF06DFF

# Premaster Secret (S)
F1036FEC D017C823 9C0D5AF7 E0FCF0D4 08B009E3 6411618A 60B23AAB BFC38339
72682312 14BAACDC 94CA1C53 F442FB51 C1B027C3 18AE238E 16414D60 D1881B66
486ADE10 ED02BA33 D098F6CE 9BCF1BB0 C46CA2C4 7F2F174C 59A9C61E 2560899B
83EF6113 1E6FB30B 714F4E43 B735C9FE 6080477C 1B83E409 3E4D456B 9BCA492C
F9339D45 BC42E67C E6C02C24 3E49F5DA 42A869EC 855780E8 4207B8A1 EA6501C4
78AAC0DF D3D22614 F531A00D 826B7954 AE8B14A9 85A42931 5E6DD366 4CF47181

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


33


5. Pairing

```
496A9432 9CDE8005 CAE63C2F 9CA4969B FE840019 24037C44 6559BDBB 9DB9D4DD
142FBCD7 5EEF2E16 2C843065 D99E8F05 762C4DB7 ABD9DB20 3D41AC85 A58C05BD
4E2DBF82 2A934523 D54E0653 D376CE8B 56DCB452 7DDDC1B9 94DC7509 463A7468
D7F02B1B EB168571 4CE1DD1E 71808A13 7F788847 B7C6B7BF A1364474 B3B7E894
78954F6A 8E68D45B 85A88E4E BFEC1336 8EC0891C 3BC86CF5 00978801 78D86135
E7287234 58538858 D715B7B2 47406222 C1019F53 603F0169 52D49710 0858824C

# Session Key (K)
5CBC219D B052138E E1148C71 CD449896 3D682549 CE91CA24 F098468F 06015BEB
6AF245C2 093F98C3 651BCA83 AB8CAB2B 580BBF02 184FEFDF 26142F73 DF95AC50

##### 5.6 Pair Setup

```

The Pair Setup procedure requires the user to enter the accessoryʼs password on the iOS device to bidirectionally
authenticate. The Pair Setup procedure follows the Secure Remote Password protocol. This process assumes that
the accessory is unpaired and in a mode that enables pairing to be initiated.


All pairing identifiers in the Pair Setup procedure are case-sensitive.


Every accessory must support a manufacturer-defined mechanism to restore itself to a “factory reset” state where all
pairing information is erased and restored to factory default settings. This mechanism should be easily accessible to
a user, e.g. a physical button or a reset code.


**Note:** The C functions referenced in this section refer to the SRP C API defined by _`[http://srp.](http://srp.stanford.edu)`_

_`[stanford.edu](http://srp.stanford.edu)`_ . If you are using a different SRP implementation, youʼll need to use the equivalent functions in your library.


5.6.1 M1: iOS Device - _>_ Accessory – ‘SRP Start Requestʼ


When the iOS device performs authentication as part of the Pair Setup procedure, it sends a request to the accessory
with the following TLV items:


_`kTLVType_State`_ _<_ _`M1`_ _>_

_`kTLVType_Method`_ _<_ _`Pair Setup with Authentication`_ _>_


When the iOS device performs Pair Setup with a separate optional authentication procedure, it sends a request to the
accessory with the following TLV items:


_`kTLVType_State`_ _<_ _`M1`_ _>_

_`kTLVType_Method`_ _<_ _`Pair Setup`_ _>_

_`kTLVType_Flags`_ _<_ _`Pairing Type Flags`_ _>_


To learn more, see Table 5-7 Pairing Type Flags (page 51).


5.6.2 M2: Accessory - _>_ iOS Device – ‘SRP Start Responseʼ


When the accessory receives _<_ _`M1`_ _>_, it must perform the following steps:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


34


5. Pairing


1. If the accessory is already paired, it must respond with the following TLV items:


_`kTLVType_State`_ _<_ _`M2`_ _>_

_`kTLVType_Error`_ _<_ _`kTLVError_Unavailable`_ _>_


2. If the accessory has received more than 100 unsuccessful authentication attempts, it must respond with the
following TLV items:


_`kTLVType_State`_ _<_ _`M2`_ _>_

_`kTLVType_Error`_ _<_ _`kTLVError_MaxTries`_ _>_


3. If the accessory is currently performing a Pair Setup procedure with a different controller, it must respond with
the following TLV items:


_`kTLVType_State`_ _<_ _`M2`_ _>_

_`kTLVType_Error`_ _<_ _`kTLVError_Busy`_ _>_


4. Create new SRP session with _`SRP_new( SRP6a_server_method() )`_ .


5. Set SRP username to _`Pair-Setup`_ with _`SRP_set_username()`_ .


6. Generate 16 bytes of random salt and set it with _`SRP_set_params()`_ .


7. If the accessory received the M1 (SRP Start Request) without _`kTLVType_Flags`_ or if the _`kTLVType_Flags`_
were set as _`kPairingFlag_Transient`_ and _`kPairingFlag_Split`_ then:


    - If the accessory can display a random setup code, it must generate a random setup code, save the SRP
verifier for that setup code, use that setup code for the next Pair Setup procedure with _`kPairingFlag_Split`_,
and set it with _`SRP_set_auth_password()`_ .

    - If the accessory cannot display a random setup code, it must retrieve the SRP verifier for the setup code,
e.g. from an EEPROM, and set the verifier with _`SRP_set_authenticator()`_ .

    - The accessory must include the received _`kTLVType_Flags`_ in its M2 response.


If the accessory received the M1 (SRP Start Request) with the _`kTLVType_Flags`_ set as _`kPairingFlag_Split`_
then:


    - If the accessory has saved SRP verifier it must retrieve the saved SRP verifier for the setup code, e.g. from
an EEPROM, and set the verifier with _`SRP_set_authenticator()`_ . The accessory must also include
the received _`kTLVType_Flags`_ in its M2 response.

    - If the accessory does not have a saved SRP verifier, it must respond with the following TLV items:

_`kTLVType_State`_ _<_ _`M2`_ _>_

_`kTLVType_Error`_ _<_ _`kTLVError_Authentication`_ _>_


The setup code must conform to the format _`XXX-XX-XXX`_ where each X is a 0-9 digit and dashes are required.
To learn more, see ”4.2.1 Setup Code” (page 29).


8. If the accessory has generated a setup code, it must present the setup code to the user, e.g. display it on the
accessoryʼs screen. If the accessory doesnʼt have a screen then the setup code may be on a printed label.


9. Generate an SRP public key with _`SRP_gen_pub()`_ .


10. Respond to the iOS deviceʼs request with the following TLV items:


_`kTLVType_State`_ _<_ _`M2`_ _>_

_`kTLVType_PublicKey`_ _<_ _`Accessory’s SRP public key`_ _>_

_`kTLVType_Salt`_ _<_ _`16 byte salt generated in Step 6`_ _>_

_`kTLVType_Flags`_ _<_ _`Pairing Type Flags`_ _>_ (Optional as per Step 7)


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


35


5. Pairing


5.6.3 M3: iOS Device - _>_ Accessory – ‘SRP Verify Requestʼ


When the iOS device receives _<_ _`M2`_ _>_, it will check for _`kTLVType_Error`_ . If present, the iOS device will abort the
setup process and report the error to the user.


If _`kTLVType_Error`_ is not present and the controller is performing only a _split pair setup_ (that is, _`kPairingFlag_Split`_
was set and _`kPairingFlag_Transient`_ was not set in M2), the controller will reuse the setup code from the previous Transient + Split Setup session. Otherwise, the user is prompted to enter the setup code provided by the accessory.


Once the setup code is available, the iOS device performs the following steps:


1. Create a new SRP session with _`SRP_new( SRP6a_client_method() )`_ .


2. Set the SRP user name to _`Pair-Setup`_ with _`SRP_set_username()`_ .


3. Set salt provided by the accessory in the _<_ _`M2`_ _>_ TLV with _`SRP_set_params()`_ .


4. Generate its SRP public key with _`SRP_gen_pub()`_ .


5. Set the setup code as entered by the user with _`SRP_set_auth_password()`_ .


6. Compute the SRP shared secret key with _`SRP_compute_key()`_ .


7. Generate iOS device-side SRP proof with _`SRP_respond()`_ .


8. Send a request to the accessory with the following TLV items:


_`kTLVType_State`_ _<_ _`M3`_ _>_

_`kTLVType_PublicKey`_ _<_ _`iOS device’s SRP public key`_ _>_

_`kTLVType_Proof`_ _<_ _`iOS device’s SRP proof`_ _>_


5.6.4 M4: Accessory - _>_ iOS Device – ‘SRP Verify Responseʼ


When the accessory receives _<_ _`M3`_ _>_, it must perform the following steps:


1. Use the iOS deviceʼs SRP public key to compute the SRP shared secret key with _`SRP_compute_key()`_ .


2. Verify the iOS deviceʼs SRP proof with _`SRP_verify()`_ . If verification fails, the accessory must respond with

_`kTLVType_State`_ _<_ _`M4`_ _>_
the following TLV items:
```
               kTLVType_Error kTLVError_Authentication

```

3. Generate the accessory-side SRP proof with _`SRP_respond()`_ .


4. Construct the response with the following TLV items:
_`kTLVType_State`_ _<_ _`M4`_ _>_

_`kTLVType_Proof`_ _<_ _`Accessory’s SRP proof`_ _>_


5. Send the response to the iOS device.


6. If the accessory is performing a transient pair setup (i.e. _`kTLVType_Method`_ is _<_ _`Pair Setup`_ _>_ and the
kPairingFlag_Transient is set in _`kTLVType_Flags`_ ), then Pair Setup is complete for the accessory and the
accessory must enable session security with the Pair-Setup session keys generated in Step 4.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


36


5. Pairing


5.6.5 M5: iOS Device - _>_ Accessory – ‘Exchange Requestʼ


5.6.5.1 _<_ _`M4`_ _>_ Verification


When the iOS device receives _<_ _`M4`_ _>_, it performs the following steps:


1. Check for _`kTLVType_Error`_ . If present and itʼs set to _`kTLVError_Authentication`_, the user will be prompted
that the setup code was incorrect and be allowed to try again. If _`kTLVType_Error`_ is set to any other error
code, then the setup process will be aborted and an error will be reported to the user. The accessory resets to
_<_ _`M1`_ _>_ for Pair Setup.


2. Verify accessoryʼs SRP proof with _`SRP_verify()`_ . If this fails, the setup process will be aborted and an error
will be reported to the user.


5.6.5.2 _<_ _`M5`_ _>_ Request Generation


Once _<_ _`M4`_ _>_ Verification is complete, and the controller is performing a non-transient pair-setup the iOS device performs the following steps to generate the _<_ _`M5`_ _>_ request:


1. Generate its Ed25519 long-term public key, _`iOSDeviceLTPK`_, and long-term secret key, _`iOSDeviceLTSK`_, if
they donʼt exist.


2. Derive _`iOSDeviceX`_ from the SRP shared secret by using _`HKDF-SHA-512`_ with the following parameters:


_`InputKey`_ _`=`_ _<_ _`SRP shared secret`_ _>_
```
    Salt = ”Pair-Setup-Controller-Sign-Salt”
    Info = ”Pair-Setup-Controller-Sign-Info”
    OutputSize = 32 bytes

```

3. Concatenate _`iOSDeviceX`_ with the iOS deviceʼs Pairing Identifier, _`iOSDevicePairingID`_, and its long-term
public key, _`iOSDeviceLTPK`_ . The data must be concatenated in order such that the final data is _`iOSDeviceX,`_

_`iOSDevicePairingID, iOSDeviceLTPK`_ . The concatenated value will be referred to as _`iOSDeviceInfo`_ .


4. Generate _`iOSDeviceSignature`_ by signing _`iOSDeviceInfo`_ with its long-term secret key, _`iOSDeviceLTSK`_,
using Ed25519.


_`kTLVType_Identifier`_ _<_ _`iOSDevicePairingID`_ _>_



5. Construct a sub-TLV with the following TLV items:



_`kTLVType_PublicKey`_ _<_ _`iOSDeviceLTPK`_ _>_

_`kTLVType_Signature`_ _<_ _`iOSDeviceSignature`_ _>_



6. Encrypt the sub-TLV, _`encryptedData`_, and generate the 16 byte auth tag, _`authTag`_ . This uses the
ChaCha20-Poly1305 AEAD algorithm with the following parameters:
```
  encryptedData, authTag = ChaCha20-Poly1305(SessionKey, Nonce=”PS-Msg05”,
  AAD=<none>, Msg=<Sub-TLV>)

```

7. Send the request to the accessory with the following TLV items:
_`kTLVType_State`_ _<_ _`M5`_ _>_

_`kTLVType_EncryptedData`_ _<_ _`encryptedData with authTag appended`_ _>_


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


37


5. Pairing


5.6.6 M6: Accessory - _>_ iOS Device – ‘Exchange Responseʼ


5.6.6.1 _<_ _`M5`_ _>_ Verification


When the accessory receives _<_ M5 _>_, it must perform the following steps:


1. Verify the iOS deviceʼs _`authTag`_, which is appended to the _`encryptedData`_ and contained within the

_`kTLVType_EncryptedData`_ TLV item, from _`encryptedData`_ . If verification fails, the accessory must respond with the following TLV items:


_`kTLVType_State`_ _<_ _`M6`_ _>_
```
    kTLVType_Error kTLVError_Authentication

```

2. Decrypt the sub-TLV in _`encryptedData`_ . If decryption fails, the accessory must respond with the following
TLV items:

_`kTLVType_State`_ _<_ _`M6`_ _>_
```
    kTLVType_Error kTLVError_Authentication

```

3. Derive _`iOSDeviceX`_ from the SRP shared secret by using _`HKDF-SHA-512`_ with the following parameters:
_`InputKey`_ _`=`_ _<_ _`SRP shared secret`_ _>_
```
    Salt = ”Pair-Setup-Controller-Sign-Salt”
    Info = ”Pair-Setup-Controller-Sign-Info”
    OutputSize = 32 bytes

```

4. Construct _`iOSDeviceInfo`_ by concatenating _`iOSDeviceX`_ with the iOS deviceʼs Pairing Identifier,

_`iOSDevicePairingID`_, from the decrypted sub-TLV and the iOS deviceʼs long-term public key,

_`iOSDeviceLTPK`_ from the decrypted sub-TLV. The data must be concatenated in order such that the final
data is _`iOSDeviceX, iOSDevicePairingID, iOSDeviceLTPK`_ .


5. Use Ed25519 to verify the signature of the constructed _`iOSDeviceInfo`_ with the _`iOSDeviceLTPK`_ from the
decrypted sub-TLV. If signature verification fails, the accessory must respond with the following TLV items:
_`kTLVType_State`_ _<_ _`M6`_ _>_
```
    kTLVType_Error kTLVError_Authentication

```

6. Persistently save the _`iOSDevicePairingID`_ and _`iOSDeviceLTPK`_ as a pairing. If the accessory cannot
accept any additional pairings, it must respond with the following TLV items:
_`kTLVType_State`_ _<_ _`M6`_ _>_
```
    kTLVType_Error kTLVError_MaxPeers

```

5.6.6.2 _<_ _`M6`_ _>_ Response Generation


Once _<_ _`M5`_ _>_ Verification is complete, the accessory must perform the following steps to generate the _<_ _`M6`_ _>_ response:


1. Generate its Ed25519 long-term public key, _`AccessoryLTPK`_, and long-term secret key, _`AccessoryLTSK`_, if
they donʼt exist.


2. Derive _`AccessoryX`_ from the SRP shared secret by using _`HKDF-SHA-512`_ with the following parameters:


_`InputKey`_ _`=`_ _<_ _`SRP shared secret`_ _>_
```
    Salt = ”Pair-Setup-Accessory-Sign-Salt”
    Info = ”Pair-Setup-Accessory-Sign-Info”
    OutputSize = 32 bytes

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


38


5. Pairing


3. Concatenate _`AccessoryX`_ with the accessoryʼs Pairing Identifier, _`AccessoryPairingID`_, and its long-term
public key, _`AccessoryLTPK`_ . The data must be concatenated in order such that the final data is _`AccessoryX,`_

_`AccessoryPairingID, AccessoryLTPK`_ . The concatenated value will be referred to as _`AccessoryInfo`_ .


4. Use Ed25519 to generate _`AccessorySignature`_ by signing _`AccessoryInfo`_ with its long-term secret key,

_`AccessoryLTSK`_ .


_`kTLVType_Identifier`_ _<_ _`AccessoryPairingID`_ _>_



5. Construct the sub-TLV with the following TLV items:



_`kTLVType_PublicKey`_ _<_ _`AccessoryLTPK`_ _>_

_`kTLVType_Signature`_ _<_ _`AccessorySignature`_ _>_



6. Encrypt the sub-TLV, _`encryptedData`_, and generate the 16 byte auth tag, _`authTag`_ . This uses the
ChaCha20-Poly1305 AEAD algorithm with the following parameters:
```
   encryptedData, authTag = ChaCha20-Poly1305(SessionKey, Nonce=”PS-Msg06”,
   AAD=<none>, Msg=<Sub-TLV>)

```

7. Send the response to the iOS device with the following TLV items:
_`kTLVType_State`_ _<_ _`M6`_ _>_

_`kTLVType_EncryptedData`_ _<_ _`encryptedData with authTag appended`_ _>_


5.6.6.3 _<_ _`M6`_ _>_ Verification by iOS Device


When the iOS device receives _<_ _`M6`_ _>_, it performs the following steps:


1. Verifies _`authTag`_, which is appended to the _`encryptedData`_ and contained within the

_`kTLVType_EncryptedData`_ TLV item, from _`encryptedData`_ . If this fails, the setup process will be aborted
and an error will be reported to the user.


2. Decrypts the sub-TLV in _`encryptedData`_ . If this fails, the setup process will be aborted and an error will be
reported to the user.


3. Uses Ed25519 to verify the signature of _`AccessoryInfo`_ using _`AccessoryLTPK`_ . If this fails, the setup
process will be aborted and an error will be reported to the user.


4. Persistently saves _`AccessoryPairingID`_ and _`AccessoryLTPK`_ as a pairing.


The Pair Setup procedure is now complete.

##### 5.7 Pair Verify


Once a pairing has been established, it must be verified each time it is used. The Pair Verify procedure uses the Stationto-Station protocol to perform bidirectional authentication and results in a mutually authenticated shared secret for
future session security.


All pairing identifiers in Pair Verify are case-sensitive.


The following describes the flow of messages to verify pairing.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


39


5. Pairing


5.7.1 M1: iOS Device - _>_ Accessory – ‘Verify Start Requestʼ


The iOS device generates a new, random Curve25519 key pair and sends a request to the accessory with the following
TLV items:


_`kTLVType_State`_ _<_ _`M1`_ _>_

_`kTLVType_PublicKey`_ _<_ _`iOS device’s Curve25519 public key`_ _>_


5.7.2 M2: Accessory - _>_ iOS Device – ‘Verify Start Responseʼ


When the accessory receives _<_ _`M1`_ _>_, it must perform the following steps:


1. Generate new, random Curve25519 key pair.


2. Generate the shared secret, _`SharedSecret`_, from its Curve25519 secret key and the iOS deviceʼs Curve25519
public key.


3. Construct _`AccessoryInfo`_ by concatenating the following items in order:


(a) Accessoryʼs Curve25519 public key.


(b) Accessoryʼs Pairing Identifier, _`AccessoryPairingID`_ .


(c) iOS deviceʼs Curve25519 public key from the received _<_ _`M1`_ _>_ TLV.


4. Use Ed25519 to generate _`AccessorySignature`_ by signing _`AccessoryInfo`_ with its long-term secret key,

_`AccessoryLTSK`_ .


_`kTLVType_Identifier`_ _<_ _`AccessoryPairingID`_ _>_
5. Construct a sub-TLV with the following items:

_`kTLVType_Signature`_ _<_ _`AccessorySignature`_ _>_


6. Derive the symmetric session encryption key, _`SessionKey`_, from the Curve25519 shared secret by using

_`HKDF-SHA-512`_ with the following parameters:


_`InputKey`_ _`=`_ _<_ _`Curve25519 shared secret`_ _>_
```
    Salt = ”Pair-Verify-Encrypt-Salt”
    Info = ”Pair-Verify-Encrypt-Info”
    OutputSize = 32 bytes

```

7. Encrypt the sub-TLV, _`encryptedData`_, and generate the 16-byte auth tag, _`authTag`_ . This uses the
ChaCha20-Poly1305 AEAD algorithm with the following parameters:
```
   encryptedData, authTag = ChaCha20-Poly1305(SessionKey, Nonce=”PV-Msg02”,
   AAD=<none>, Msg=<Sub-TLV>)

```

8. Construct the response with the following TLV items:
_`kTLVType_State`_ _<_ _`M2`_ _>_

_`kTLVType_PublicKey`_ _<_ _`Accessory’s Curve25519 public key`_ _>_

_`kTLVType_EncryptedData`_ _<_ _`encryptedData with authTag appended`_ _>_


9. Send the response to the iOS device.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


40


5. Pairing


5.7.3 M3: iOS Device - _>_ Accessory – ‘Verify Finish Requestʼ


When the iOS device receives _<_ _`M2`_ _>_, it performs the following steps:


1. Generate the shared secret, _`SharedSecret`_, from its Curve25519 secret key and the accessoryʼs Curve25519
public key.


2. Derive the symmetric session encryption key, _`SessionKey`_, in the same manner as the accessory.


3. Verify the 16-byte auth tag, _`authTag`_, against the received _`encryptedData`_ . If this fails, the setup process
will be aborted and an error will be reported to the user.


4. Decrypt the sub-TLV from the received _`encryptedData`_ .


5. Use the accessoryʼs Pairing Identifier to look up the accessoryʼs long-term public key, _`AccessoryLTPK`_, in its
list of paired accessories. If not found, the setup process will be aborted and an error will be reported to the
user.


6. Use Ed25519 to verify _`AccessorySignature`_ using _`AccessoryLTPK`_ against _`AccessoryInfo`_ . If this fails,
the setup process will be aborted and an error will be reported to the user.


7. Construct _`iOSDeviceInfo`_ by concatenating the following items in order:


(a) iOS Deviceʼs Curve25519 public key.


(b) iOS Deviceʼs Pairing Identifier, _`iOSDevicePairingID`_ .


(c) Accessoryʼs Curve25519 public key from the received _<_ _`M2`_ _>_ TLV.


8. Use Ed25519 to generate _`iOSDeviceSignature`_ by signing _`iOSDeviceInfo`_ with its long-term secret key,

_`iOSDeviceLTSK`_ .


_`kTLVType_Identifier`_ _<_ _`iOSDevicePairingID`_ _>_
9. Construct a sub-TLV with the following items:

_`kTLVType_Signature`_ _<_ _`iOSDeviceSignature`_ _>_


10. Encrypt the sub-TLV, _`encryptedData`_, and generate the 16-byte auth tag, _`authTag`_ . This uses the
ChaCha20-Poly1305 AEAD algorithm with the following parameters:
```
   encryptedData, authTag = ChaCha20-Poly1305(SessionKey, Nonce=”PV-Msg03”,
   AAD=<none>, Msg=<Sub-TLV>)

```

11. Construct the request with the following TLV items:
_`kTLVType_State`_ _<_ _`M3`_ _>_

_`kTLVType_EncryptedData`_ _<_ _`encryptedData with authTag appended`_ _>_


12. Send the request to the accessory.


5.7.4 M4: Accessory - _>_ iOS Device – ‘Verify Finish Responseʼ


When the accessory receives _<_ _`M3`_ _>_, it must perform the following steps:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


41


5. Pairing


1. Verify the iOS deviceʼs _`authTag`_, which is appended to the _`encryptedData`_ and contained within the

_`kTLVType_EncryptedData`_ TLV item, against _`encryptedData`_ . If verification fails, the accessory must respond with the following TLV items:

_`kTLVType_State`_ _<_ _`M4`_ _>_
```
    kTLVType_Error kTLVError_Authentication

```

2. Decrypt the sub-TLV in _`encryptedData`_ . If decryption fails, the accessory must respond with the following
TLV items:

_`kTLVType_State`_ _<_ _`M4`_ _>_
```
    kTLVType_Error kTLVError_Authentication

```

3. Use the iOS deviceʼs Pairing Identifier, _`iOSDevicePairingID`_, to look up the iOS deviceʼs long-term public key, _`iOSDeviceLTPK`_, in its list of paired controllers. If not found, the accessory must respond with the
following TLV items:

_`kTLVType_State`_ _<_ _`M4`_ _>_
```
    kTLVType_Error kTLVError_Authentication

```

4. Use Ed25519 to verify _`iOSDeviceSignature`_ using _`iOSDeviceLTPK`_ against _`iOSDeviceInfo`_ contained
in the decrypted sub-TLV. If decryption fails, the accessory must respond with the following TLV items:

_`kTLVType_State`_ _<_ _`M4`_ _>_
```
    kTLVType_Error kTLVError_Authentication

```

5. Send the response to the iOS device with the following TLV items: _`kTLVType_State`_ _<_ _`M4`_ _>_


When the iOS device receives _<_ _`M4`_ _>_, the Pair Verify procedure is complete. If a subsequent Pair Verify request from
another controller occurs in the middle of a Pair Verify transaction the accessory must honor both Pair Verify requests
and maintain separate secure sessions for each controller. If a subsequent Pair Verify request from the same controller
occurs in the middle of the Pair Verify procedure then the accessory must immediately tear down the existing session
with the controller and must accept the newest request.

##### 5.8 Fragmentation and Reassembly


Some transports, like Bluetooth LE, have limits on the maximum amount of data that can be exchanged per transaction.
To support these transports, pairing requests and responses may need to be fragmented when sent and reassembled
when received. All fragments except the last must use the _`kTLVType_FragmentData`_ TLV type. The last fragment
must use the _`kTLVType_FragmentLast`_ TLV type.


The ”value” of these TLV items is the next portion of data from the original pairing TLV that will fit in the current MTU.
When a non-last fragment is received, it is appended to the reassembly buffer and a _`kTLVType_FragmentData`_ item
is sent back with an empty ”value” section. This acknowledges the fragment so the next fragment can be sent.


When the last fragment is received, the reassembled TLV is processed normally. Fragments must be sent and received
in order. Fragmentation may occur on a per-request/response basis. Requests or responses that fit within the MTU
of the transport must be sent as-is and not fragmented.

##### 5.9 AEAD Algorithm


[When data is encrypted or decrypted, it uses the ChaCha20-Poly1305 AEAD algorithm as defined in RFC 7539. This](https://tools.ietf.org/html/rfc7539)
document uses the 64-bit nonce option where the first 32 bits of 96-bit nonce are 0.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


42


5. Pairing

##### 5.10 Add Pairing


The Add Pairing procedure is used to exchange long-term public keys to establish a pairing relationship for an additional controller. The Add Pairing procedure can only be performed by admin controllers, that have established a
secure session with the accessory using the ”5.7 Pair Verify” (page 39) procedure. Authenticated encryption is used
for all encrypted data.


The minimum number of pairing relationships that an accessory must support is _16_ .


5.10.1 M1: iOS Device - _>_ Accessory – ‘Add Pairing Requestʼ


The iOS device performs the following steps:


1. Get the Pairing Identifier, _`AdditionalControllerPairingIdentifier`_, and the Ed25519 long-term public key of the additional controller to pair, _`AdditionalControllerLTPK`_, via an out-of-band mechanism.


2. Construct the request TLV with the following items:
_`kTLVType_State`_ _<_ _`M1`_ _>_

_`kTLVType_Method`_ _<_ _`Add Pairing`_ _>_
```
    kTLVType_Identifier AdditionalControllerPairingIdentifier
    kTLVType_PublicKey AdditionalControllerLTPK
    kTLVType_Permissions AdditionalControllerPermissions

```

3. Send the TLV over the HAP session established via ”5.7 Pair Verify” (page 39), which provides bidirectional,
authenticated encryption.


5.10.2 M2: Accessory - _>_ iOS Device – ‘Add Pairing Responseʼ


When the accessory receives the request, it must perform the following steps:


1. Validate the received data against the established HAP session as described in the transport-specific chapters.


2. Verify that the controller sending the request has the admin bit set in the local pairings list. If not, accessory
must abort and respond with the following TLV items:
_`kTLVType_State`_ _<_ _`M2`_ _>_
```
    kTLVType_Error kTLVError_Authentication

```

3. If a pairing for _`AdditionalControllerPairingIdentifier`_ exists, it must perform the following steps:


(a) If the _`AdditionalControllerLTPK`_ does not match the stored long-term public key for

_`AdditionalControllerPairingIdentifier`_, respond with the following TLV items:
_`kTLVType_State`_ _<_ _`M2`_ _>_
```
      kTLVType_Error kTLVError_Unknown
```

(b) Update the permissions of the controller to match _`AdditionalControllerPermissions`_ .


4. Otherwise, if a pairing for _`AdditionalControllerPairingIdentifier`_ does not exist, it must perform
the following steps:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


43


5. Pairing


(a) Check if the accessory has space to support an additional pairing; the minimum number of supported
pairings is 16 pairings. If not, accessory must abort and respond with the following TLV items:
_`kTLVType_State`_ _<_ _`M2`_ _>_
```
      kTLVType_Error kTLVError_MaxPeers
```

(b) Save the additional controllerʼs _`AdditionalControllerPairingIdentifier`_, _`AdditionalControllerLTPK`_
and _`AdditionalControllerPermissions`_ to a persistent store. If an error occurs while saving, accessory must abort and respond with the following TLV items:
_`kTLVType_State`_ _<_ _`M2`_ _>_
```
      kTLVType_Error kTLVError_Unknown

```

5. Construct a response with the following TLV items:

_`kTLVType_State`_ _<_ _`M2`_ _>_


6. Send the response over the HAP session established via ”5.7 Pair Verify” (page 39), which provides bidirectional, authenticated encryption.


When the iOS device receives this response, it performs the following steps:


1. Validate the received data against the established HAP session.


2. Validate that the received TLV contains no errors.


3. Send the accessoryʼs long-term public key and Pairing Identifier to the additional controller via an out-of-band
mechanism.

##### 5.11 Remove Pairing


The Remove Pairing procedure removes previously established pairings. The Remove Pairing procedure can only be
performed by admin controllers that have established a secure session with the accessory using the ”5.7 Pair Verify”
(page 39) procedure. Authenticated encryption is used for all encrypted data.


Once the Remove Pairing procedure is completed, the accessory must tear down any existing connections with the
removed controller within 5 seconds. The accessory must refuse all connection requests until all of the existing connections are closed and return the appropriate transport specific HAP Status codes in the response:


1. IP: -70401 (Table 6-11 (page 67))


2. BLE: 0x03 (Table 7-37 (page 110))


If the last remaining admin controller pairing is removed, all pairings on the accessory must be removed.


5.11.1 M1: iOS Device - _>_ Accessory – ‘Remove Pairing Requestʼ


The iOS device performs the following steps:


1. Get the Pairing Identifier of the additional controller to remove, _`RemovedControllerPairingIdentifier`_,
via an out-of-band mechanism.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


44


5. Pairing


2. Construct the request TLV with the following items:
_`kTLVType_State`_ _<_ _`M1`_ _>_

_`kTLVType_Method`_ _<_ _`Remove Pairing`_ _>_
```
    kTLVType_Identifier RemovedControllerPairingIdentifier

```

3. Send the TLV over the HAP session established via ”5.7 Pair Verify” (page 39), which provides bidirectional,
authenticated encryption.


5.11.2 M2: Accessory - _>_ iOS Device – ‘Remove Pairing Responseʼ


When the accessory receives the request, it must perform the following steps:


1. Validate the received data against the established HAP session as described in the transport-specific chapters.


2. Verify that the controller sending the request has the admin bit set in the local pairings list. If not, accessory
must abort and respond with the following TLV items:
_`kTLVType_State`_ _<_ _`M2`_ _>_
```
    kTLVType_Error kTLVError_Authentication

```

3. If the pairing exists, remove _`RemovedControllerPairingIdentifier`_ and its corresponding long-term
public key from persistent storage. If a pairing for _`RemovedControllerPairingIdentifier`_ does not exist,
the accessory must return success. Otherwise, if an error occurs during removal, accessory must abort and
respond with the following TLV items:
_`kTLVType_State`_ _<_ _`M2`_ _>_
```
    kTLVType_Error kTLVError_Unknown

```

4. Construct a response with the following TLV items: _`kTLVType_State`_ _<_ _`M2`_ _>_


5. Send the response over the HAP session established via ”5.7 Pair Verify” (page 39), which provides bidirectional, authenticated encryption.


6. If the controller requested the accessory to remove its own pairing the accessory must invalidate the HAP
session immediately after the response is sent.


7. If there are any established HAP sessions with the controller that was removed, then these connections must
be immediately torn down and any associated data stream (e.g. RTP, HDS) must be stopped and removed.

##### 5.12 List Pairings


The List Pairings procedure is used to read a list of all the currently established pairings. The List Pairings procedure
can only be performed by controllers that have been through ”5.6 Pair Setup” (page 34) with the accessory and have
established a shared secret via ”5.7 Pair Verify” (page 39). Authenticated encryption is used for all encrypted data.


This is used to read a list of all the currently established pairings. Itʼs a read with a response over an HAP session
established via ”5.7 Pair Verify” (page 39), which provides bidirectional, authenticated encryption. The response is
a group of TLV items with separator items to delineate them. Each pairing entry must be comprised of the following
TLV items:


_`kTLVType_Identifier`_ _<_ _`Pairing Identifier of Controller 1`_ _>_

_`kTLVType_PublicKey`_ _<_ _`Ed25519 long-term public key of Controller 1`_ _>_

_`kTLVType_Permissions`_ _<_ _`Bit value describing permissions of Controller 1`_ _>_


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


45


5. Pairing


5.12.1 M1: iOS Device - _>_ Accessory – ‘List Pairings Requestʼ


The iOS device performs the following steps:


_`kTLVType_State`_ _<_ _`M1`_ _>_
1. Construct the request TLV with the following items:

_`kTLVType_Method`_ _<_ _`List Pairings`_ _>_


2. Send the TLV over the HAP session established via ”5.7 Pair Verify” (page 39), which provides bidirectional,
authenticated encryption.


5.12.2 M2: Accessory - _>_ iOS Device – ‘List Pairings Responseʼ


When the accessory receives the request, it must perform the following steps:


1. Validate the received data against the established HAP session as described in the transport-specific chapters.


2. Verify that the controller sending the request has the admin bit set in the local pairings list. If not, abort and

_`kTLVType_State`_ _<_ _`M2`_ _>_
respond with the following TLV items:
```
                     kTLVType_Error kTLVError_Authentication

```

3. Construct a response with the following TLV items:
_`kTLVType_State`_ _<_ _`M2`_ _>_

_`kTLVType_Identifier`_ _<_ _`Pairing Identifier of Controller 1`_ _>_

_`kTLVType_PublicKey`_ _<_ _`Ed25519 long-term public key of Controller 1`_ _>_

_`kTLVType_Permissions`_ _<_ _`Bit value describing permissions of Controller 1`_ _>_

If another pairing follows a pairing, it must be separated using a separator item:

_`kTLVType_Separator`_ _<_ _`No value`_ _>_


Additional pairings must contain the following TLV items:
_`kTLVType_Identifier`_ _<_ _`Pairing Identifier of Controller N`_ _>_

_`kTLVType_PublicKey`_ _<_ _`Ed25519 long-term public key of Controller N`_ _>_

_`kTLVType_Permissions`_ _<_ _`Bit value describing permissions of Controller N`_ _>_


4. Send the response over the HAP session established via ”5.7 Pair Verify” (page 39), which provides bidirectional, authenticated encryption.

##### 5.13 Pairing over Bluetooth LE


When pairing over Bluetooth LE, the accessory advertises a pairing service. Pairing requests are performed by writing
to characteristics of this service. Pairing responses are performed by subsequently reading characteristics of this
service. The read response must be sent within 30 seconds of the read request. The maximum payload size for an HAP
Characteristic value over HAP Bluetooth LE must not exceed 512 bytes ”7.4.1.7 Maximum Payload Size” (page 116).
Pairing payloads with certificates will exceed 512 bytes and require payload fragmentation to be delivered, therefore
accessories must support fragmentation per ”5.8 Fragmentation and Reassembly” (page 42).


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


46


5. Pairing



5.13.1 Pairing Service


Defines characteristics to support pairing between a controller and an accessory.



|Property|Value|
|---|---|
|**UUID**|00000055-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.pairing|
|**Required Characteristics**|”5.13.1.1 Pair Setup” (page 47)<br>”5.13.1.2 Pair Verify” (page 47)<br>”5.13.1.3 Pairing Features” (page 47)<br>”5.13.1.4 Pairing Pairings” (page 48)|


5.13.1.1 Pair Setup





Accessories must accept reads and writes to this characteristic to perform Pair Setup.

|Property|Value|
|---|---|
|**UUID**|0000004C-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.pairing.pair-setup|
|**Permissions**|Read, Write|
|**Format**|tlv8|



5.13.1.2 Pair Verify


Accessories must accept reads and writes to this characteristic to perform the Pair Verify procedure.

|Property|Value|
|---|---|
|**UUID**|0000004E-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.pairing.pair-verify|
|**Permissions**|Read, Write|
|**Format**|tlv8|



5.13.1.3 Pairing Features


Read-only characteristic that exposes pairing features must be supported by the accessory. See Table 5-4 (page 49).


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


47


5. Pairing

|Property|Value|
|---|---|
|**UUID**|0000004F-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.pairing.features|
|**Permissions**|Read|
|**Format**|uint8|



5.13.1.4 Pairing Pairings


Accessories must accept reads and writes to this characteristic to add, remove, and list pairings.

|Property|Value|
|---|---|
|**UUID**|00000050-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.pairing.pairings|
|**Permissions**|Paired Read, Paired Write|
|**Format**|tlv8|


##### 5.14 Pairing over IP


When pairing over an IP network, HTTP is used as the transport. Pairing requests are performed by sending a POST
request to the accessoryʼs HTTP server unless otherwise noted. The URL resource specifies the pairing operation to
perform. The body of the HTTP request contains the TLV data. Pairing responses are delivered as TLV data in the body
of the HTTP response. The MIME type for requests and responses is _`application/pairing+tlv8`_ . Discovery of
the HTTP serverʼs IP address, port, and supported features is required to be supported via Bonjour, please see the
”6 HomeKit Accessory Protocol for IP Accessories” (page 52).


**Table 5-1:** HTTP Status Codes

|Status Code|Description|
|---|---|
|200 OK|Success.|
|400 Bad Request|Generic error for a problem with the request, e.g. bad TLV, state error,<br>etc.|
|405 Method Not Allowed|Wrong HTTP request method, e.g. GET when expecting POST.|
|429 Too Many Requests|Server cannot handle any more requests of this type, e.g. attempt to<br>pair while already pairing.|
|470 Connection Authorization Required|Request to secure resource made without establishing security, e.g.<br>didnʼt perform the Pair Verify procedure.|
|500 Internal Server Error|Server had a problem, e.g. ran out of memory.|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


48


5. Pairing


**Table 5-2:** HTTP URLs

|Status Code|Description|
|---|---|
|/pair-setup|Used in the Pair Setup procedure.|
|/pair-verify|Used in the Pair Verify procedure.|
|/pairings|Used for adding, removing, and listing pairings. Always sends HTTP POST with TLV8 pay-<br>loads defined in ”5.10 Add Pairing” (page 43), ”5.11 Remove Pairing” (page 44), and ”5.12 List<br>Pairings” (page 45).|
|/secure-message|Used to exchange HAP PDU messages after a secure session is established.|


##### 5.15 Methods, Error Codes, and TLV Values


**Table 5-3:** Methods

|Value|Description|
|---|---|
|0|Pair Setup|
|1|Pair Setup with Auth|
|2|Pair Verify|
|3|Add Pairing|
|4|Remove Pairing|
|5|List Pairings|
|6-255|Reserved|



**Table 5-4:** Pairing Feature Flags

|Mask|Bit|Description|
|---|---|---|
|_`0x04-0x80`_|3-8|Reserved.|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


49


5. Pairing


**Table 5-5:** Error Codes

|Value|Name|Description|
|---|---|---|
|_`0x00`_|n/a|Reserved.|
|_`0x01`_|_`kTLVError_Unknown`_|Generic error to handle unexpected errors.|
|_`0x02`_|_`kTLVError_Authentication`_|Setup code or signature verification failed.|
|_`0x03`_|_`kTLVError_Backoff`_|Client must look at the retry delay TLV item and wait that many<br>seconds before retrying.|
|_`0x04`_|_`kTLVError_MaxPeers`_|Server cannot accept any more pairings.|
|_`0x05`_|_`kTLVError_MaxTries`_|Server reached its maximum number of authentication at-<br>tempts.|
|_`0x06`_|_`kTLVError_Unavailable`_|Server pairing method is unavailable.|
|_`0x07`_|_`kTLVError_Busy`_|Server is busy and cannot accept a pairing request at this time.|
|_`0x08-0xFF`_|n/a|Reserved.|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


50


5. Pairing


**Table 5-6:** TLV Values

|Type|Name|Format|Description|
|---|---|---|---|
|_`0x00`_|kTLVType_Method|integer|Method to use for pairing. See Table 5-3 (page 49).|
|_`0x01`_|kTLVType_Identifier|UTF-8|Identifier for authentication.|
|_`0x02`_|kTLVType_Salt|bytes|16+ bytes of random salt.|
|_`0x03`_|kTLVType_PublicKey|bytes|Curve25519, SRP public key, or signed Ed25519 key.|
|_`0x04`_|kTLVType_Proof|bytes|Ed25519 or SRP proof.|
|_`0x05`_|kTLVType_EncryptedData|bytes|Encrypted data with auth tag at end.|
|_`0x06`_|kTLVType_State|integer|State of the pairing process. 1=M1, 2=M2, etc.|
|_`0x07`_|kTLVType_Error|integer|Error code. Must only be present if error code is not 0. See Ta-<br>ble 5-5 (page 50).|
|_`0x08`_|kTLVType_RetryDelay|integer|Seconds to delay until retrying a setup code.|
|_`0x09`_|kTLVType_Certificate|bytes|X.509 Certificate.|
|_`0x0A`_|kTLVType_Signature|bytes|Ed25519|
|_`0x0B`_|kTLVType_Permissions|integer|Bit value describing permissions of the controller being added.<br>None (_`0x00`_) : Regular user<br>Bit 1 (_`0x01`_) : Admin that is able to add and remove pairings<br>against the accessory.|
|_`0x0C`_|kTLVType_FragmentData|bytes|Non-last fragment of data. If length is 0, itʼs an ACK.|
|_`0x0D`_|kTLVType_FragmentLast|bytes|Last fragment of data.|
|_`0x13`_|kTLVType_Flags|integer|Pairing Type Flags (32 bit unsigned integer).<br>See Table 5-7<br>(page 51)|
|_`0xFF`_|kTLVType_Separator|null|Zero-length TLV that separates different TLVs in a list.|



**Table 5-7:** Pairing Type Flags

|Mask|Bit|Description|
|---|---|---|
|_`0x00000010`_|4|BitMask (1 « 4) Transient Pair-Setup (kPairingFlag_Transient)<br>Pair Setup M1 - M4 without exchanging public keys|
|_`0x01000000`_|24|BitMask (1 « 24) Split-Pair Setup (kPairingFlag_Split)<br>When Set with kPairingFlag_Transient save the SRP Verifier used in this session, and<br>when only kPairingFlag_Split is set, use the saved SRP verifier from previous session.|
|_`others`_|others|Reserved.|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


51


### 6 HomeKit Accessory Protocol for IP Accessories

##### 6.1 Overview

This chapter describes the HomeKit Accessory Protocol (HAP) for IP accessories.

##### 6.2 Requirements


6.2.1 IP Requirements


  - HAP accessory servers must support IPv4.


  - HAP accessory servers must act as a DHCPv4 client.


  - HAP accessory servers may support static IPv4 addresses.


[• HAP accessory servers must support link-local IPv4 addressing as described in RFC 3927.](https://tools.ietf.org/html/rfc3927)


[• HAP accessory servers must support link-local IPv6 addressing as described in RFC 4862.](https://tools.ietf.org/html/rfc4862)


  - HAP accessory servers must support simultaneous IPv4 and IPv6 connections.


6.2.2 Bonjour Requirements


  - HAP accessory servers must support Multicast DNS host names, e.g. ”lights.local”.


[• HAP accessory servers must handle name collisions as described in Section 9 of RFC 6762.](https://tools.ietf.org/html/rfc6762)


  - HAP accessory servers must support advertising a DNS service that includes a TXT record with multiple keys
[as described in Section 6 of RFC 6763.](https://tools.ietf.org/html/rfc6763)


  - HAP accessory servers must pass the Bonjour Conformance Test, which is available at _`[https://developer.](https://developer.apple.com/softwarelicensing/agreements/bonjour.php)`_

_`[apple.com/softwarelicensing/agreements/bonjour.php](https://developer.apple.com/softwarelicensing/agreements/bonjour.php)`_ . The HAP accessory server must pass
the following tests and all of the associated subtests:


**–** Link-local Address Allocation

**–** IPv4 Multicast-DNS

**–** IPv6 Multicast-DNS

**–** Mixed-network Interoperability


[• Refer to the Bonjour for Developers webpage for Bonjour source code and specifications.](https://developer.apple.com/bonjour/)


6.2.3 TCP Requirements


  - HAP accessory servers must support eight simultaneous TCP connections.


  - HAP accessory servers must always be able to accommodate new incoming TCP connections.


  - HAP accessory servers must not use keepalive messages, which periodically wake up iOS devices.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


52


6. HomeKit Accessory Protocol for IP Accessories


6.2.4 HTTP Server Requirements


[• The HTTP server must be HTTP/1.1 compliant as described in RFC 7230 and RFC 7231.](https://tools.ietf.org/html/rfc7230)


  - The HTTP server must support persistent connections, i.e. multiple HTTP requests through single TCP con[nection, as described in Section 6.3 of RFC 7230.](https://tools.ietf.org/html/rfc7230)


  - The HTTP server must support the HTTP URLs summarized in Table 6-14 (page 80) to service HAP clients.


6.2.5 Application Requirements


  - HAP accessory servers must be able to receive and process HAP requests at any time once the HAP Bonjour
service has been registered.


  - HAP accessory servers must support parsing and generating JavaScript Object Notation (JSON) as described
[in RFC 7159.](https://tools.ietf.org/html/rfc7159)


  - HAP accessory servers must encode JSON in UTF-8.


  - HAP accessory servers must support multiple connections.


6.2.6 General Requirements


  - HAP accessory servers must support firmware updates via all IP interfaces. For example, if the accessory server
supports both Ethernet and Wi-Fi, it must be able to update its firmware over both Ethernet and Wi-Fi.

##### 6.3 HAP Objects


6.3.1 Accessory Objects


HAP accessory objects have the following required properties.


**Table 6-1:** Properties of HAP accessory objects in JSON

|Property|Key|JSON Type|Description|
|---|---|---|---|
|Accessory Instance ID|”aid”|number|Integer assigned by the HAP Accessory Server to uniquely<br>identify the HAP Accessory object, see ”2.6.1 Instance IDs”<br>(page 26).|
|Services|”services”|array|Array of Service objects. Must not be empty. The maximum<br>number of services must not exceed 100.|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


53


6. HomeKit Accessory Protocol for IP Accessories


6.3.2 Service Objects


Service objects have the following required properties:


**Table 6-2:** Properties of Service Objects in JSON

|Property|Key|JSON Type|Description|
|---|---|---|---|
|Type|”type”|String|string that defines the type of the service. See ”6.6.1 Ser-<br>vice and Characteristic Types” (page 60).|
|Instance ID|”iid”|number|Integer assigned by the HAP Accessory Server to uniquely<br>identify the HAP Service object, see ”2.6.1 Instance IDs”<br>(page 26).|
|Characteristics|”characteristics”|array|Array of Characteristic objects. Must not be empty. The<br>maximum number of characteristics must not exceed 100,<br>and each characteristic in the array must have a unique<br>type.|
|Hidden Services|”hidden”|boolean|When set to True, this service is not visible to user.|
|Primary Services|”primary”|boolean|When set to True, this is the primary service on the acces-<br>sory.|
|Linked Services|”linked”|array|An array of numbers containing the instance ids of the ser-<br>vices that this service links to.|



6.3.3 Characteristic Objects


Characteristic objects have the following defined properties.


After an accessory has a pairing, only the values of the Value (”value”) and Event Notifications (”ev”) properties are
allowed to change.


**Table 6-3:** Properties of Characteristic Objects in JSON

|Property|Key|JSON Type|Required?|Description|
|---|---|---|---|---|
|Type|”type”|string|Yes|String that defines the type of the character-<br>istic. See ”6.6.1 Service and Characteristic<br>Types” (page 60).|
|Instance ID|”iid”|number|Yes|Integer assigned by the HAP Accessory<br>Server to uniquely identify the HAP Char-<br>acteristic object, see ”2.6.1 Instance IDs”<br>(page 26).|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


54


6. HomeKit Accessory Protocol for IP Accessories

|Value|”value”|<TYPE>|Yes|The value of the characteristic, which must<br>conform to the ”format” property. The literal<br>value null may also be used if the charac-<br>teristic has no value. This property must be<br>present if and only if the characteristic con-<br>tains the Paired Read permission, see Ta-<br>ble 6-4 (page 56).|
|---|---|---|---|---|
|Permissions|”perms”|array|Yes|Array of permission strings describing the ca-<br>pabilities of the characteristic. See Table 6-4<br>(page 56).|
|Event Notifications|”ev”|Boolean|No|Boolean indicating if event notifications are<br>enabled for this characteristic.|
|Description|”description”|string|No|String describing the characteristic on a<br>manufacturer-specific basis, such as an in-<br>door versus outdoor temperature reading.|
|Format|”format”|string|Yes|Format of the value, e.g. ”float”. See Table 6-<br>5 (page 57).|
|Unit|”unit”|string|No|Unit of the value, e.g. ”celsius”. See Table 6-<br>6 (page 57).|
|Minimum Value|”minValue”|number|No|Minimum value for the characteristic, which is<br>only appropriate for characteristics that have<br>a format of ”int” or ”float”.|
|Maximum Value|”maxValue”|number|No|Maximum value for the characteristic, which<br>is only appropriate for characteristics that<br>have a format of ”int” or ”float”.|
|Step Value|”minStep”|number|No|Minimum step value for the characteristic,<br>which is only appropriate for characteristics<br>that have a format of ”int” or ”float”.<br>For<br>example, if this were 0.15, the characteris-<br>tic value can be incremented from the min-<br>imum value in multiples of 0.15. For “float”,<br>the “Value” needs to be rounded on the ac-<br>cessory side to the closest allowed value per<br>the ”Step Value” (e.g. a value of 10.150001<br>received on the accessory side with a ”Step<br>Value” of 0.15 and a ”Minimum Value” of 10.0<br>needs to be interpreted as 10.15).|
|Max Length|”maxLen”|number|No|Maximum number of characters if the for-<br>mat is ”string”. If this property is omitted for<br>”string” formats, then the default value is 64.<br>The maximum value allowed is 256.|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


55


6. HomeKit Accessory Protocol for IP Accessories

|Max Data Length|”maxDataLen”|number|No|Maximum number of characters if the format<br>is ”data”. If this property is omitted for ”data”<br>formats, then the default value is 2097152.|
|---|---|---|---|---|
|Valid Values|”valid-values”|array|No|An array of numbers where each element rep-<br>resents a valid value.|
|Valid Values Range|”valid-values-range”|array|No|A 2 element array representing the starting<br>value and ending value of the range of valid<br>values.|
|TTL|”TTL”|number|No|Specified TTL in milliseconds the controller<br>requests the accessory to securely execute<br>a write command. Maximum value of this is<br>9007199254740991|
|PID|”pid”|number|No|64-bit unsigned integer assigned by the con-<br>troller to uniquely identify the timed write<br>transaction.|



**Table 6-4:** Characteristic Permissions

|Property|JSON String|Description|
|---|---|---|
|Paired Read|”pr”|This characteristic can only be read by paired controllers.|
|Paired Write|”pw”|This characteristic can only be written by paired controllers.|
|Events|”ev”|This characteristic supports events. The HAP Characteristic object<br>must contain the ”ev” key if it supports events.|
|Additional Authorization|”aa”|This characteristic supports additional authorization data|
|Timed Write|”tw”|This characteristic allows only timed write procedure|
|Hidden|”hd”|This characteristic is hidden from the user|
|Write Response|”wr”|This characteristic supports write response|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


56


6. HomeKit Accessory Protocol for IP Accessories


**Table 6-5:** Characteristic Value Formats

|Format JSON String|Description|
|---|---|
|”bool”|Boolean value expressed as one of the following: true, false, 0 (false), and 1 (true).|
|”uint8”|Unsigned 8-bit integer.|
|”uint16”|Unsigned 16-bit integer.|
|”uint32”|Unsigned 32-bit integer.|
|”uint64”|Unsigned 64-bit integer.|
|”int”|Signed 32-bit integer.|
|”float”|Signed 64-bit floating point number.|
|”string”|Sequence of zero or more Unicode characters, encoded as UTF-8. Maximum length is 64<br>bytes unless overridden by the ”maxLen” property.|
|”tlv8”|Base64-encoded set of one or more TLV8ʼs.|
|”data”|Base64-encoded data blob. Maximum length is 2,097,152 bytes unless overridden by the<br>”maxDataLen” property.|



**Table 6-6:** Characteristic Units

|Format JSON String|Description|
|---|---|
|”celsius”|The unit is only ”degrees Celsius”.|
|”percentage”|The unit is in percentage ”%”.|
|”arcdegrees”|The unit is in arc degrees.|
|”lux”|The unit is in lux.|
|”seconds”|The unit is in seconds.|


##### 6.4 Discovery


Accessories advertise their presence on the network via Bonjour. HAP clients browse for them and if any are found
and determined to be compatible, they are displayed to the user. The Bonjour service type is:

```
_hap._tcp

```

The name of the Bonjour service is the user-visible name of the accessory (e.g., _LED Bulb M123_ ) that must match the
name provided in the Accessory Information Service of the HAP accessory object, which has an _`instanceID`_ of 1.
This name may contain any Unicode character and is encoded using UTF-8.


The name has a maximum length of 63 bytes, which may be fewer than 63 characters as a single Unicode character
may require multiple bytes.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


57


6. HomeKit Accessory Protocol for IP Accessories


Additional data needed for discovery-time metadata is advertised via a TXT record associated with the Bonjour service.
TXT record keys are intentionally short to minimize network traffic. Accessories must confirm to the TXT records as
defined in Table 6-7 (page 58).


**Table 6-7:** _`_hap._tcp`_ Bonjour TXT Record Keys

|Key|Description|
|---|---|
|”c#”|Current configuration number. Required.<br>Must update when an accessory, service, or characteristic is added or removed on the accessory server.<br>Accessories must increment the config number after a firmware update.<br>This must have a range of 1-65535 and wrap to 1 when it overflows.<br>This value must persist across reboots, power cycles, etc.|
|”ff”|Pairing Feature flags (e.g. ”0x3” for bits 0 and 1). Required if non-zero. See Table 5-4 (page 49).|
|”id”|_`Device ID`_ (”5.4 Device ID” (page 31)) of the accessory.<br>The_` Device ID`_ must be formatted as<br>”XX:XX:XX:XX:XX:XX”, where ”XX” is a hexadecimal string representing a byte. Required.<br>This value is also used as the accessoryʼs Pairing Identifier.|
|”md”|Model name of the accessory (e.g. ”Device1,1”). Required.|
|”pv”|Protocol version string ”X.Y” (e.g. ”1.0”). Required if value is not ”1.0”.<br>(see ”6.6.3 IP Protocol Version” (page 61))|
|”s#”|Current state number. Required.<br>This must have a value of ”1”.|
|”sf”|Status flags (e.g. ”0x04” for bit 3). Value should be an unsigned integer. See Table 6-8 (page 58).<br>Required.|
|”ci”|Accessory Category Identifier. Required. Indicates the category that best describes the primary function<br>of the accessory. This must have a range of 1-65535. This must take values defined in ”13-1 Accessory<br>Categories” (page 252). This must persist across reboots, power cycles, etc.|
|”sh”|Setup Hash. See (”**?? ??**” (page** ??**)) Required if the accessory supports enhanced setup payload infor-<br>mation.|



**Table 6-8:** Bonjour TXT Status Flags

|Mask|Bit|Description|
|---|---|---|
|_`0x01`_|1|Accessory has not been paired with any controllers.|
|_`0x02`_|2|Accessory has not been configured to join a Wi-Fi network.|
|_`0x04`_|3|A problem has been detected on the accessory.|
|_`0x08-0x80`_|4-8|Reserved.|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


58


6. HomeKit Accessory Protocol for IP Accessories

##### 6.5 Security for IP Accessories


Any connection using HomeKit Accessory Protocol must be secure. Authenticated encryption for HAP is provided by
two mechanisms: pairing, which is defined in ”5 Pairing” (page 31), and session security, which is defined below.


A connection that does not use HAP should also be secured, and security negotiation for the connection should use
the HAP connection. For example, audio and video streams from an accessory to a controller should be secured using
SRTP with the SRTP security configuration itself taking place over the HAP connection.


6.5.1 Pairing


”5 Pairing” (page 31) defines a secure mechanism used to pair a controller and an accessory. The pairing is established
once and verified for every session. After the pairing has been verified, both sides have an ephemeral shared secret
that can be used to encrypt the session.


In Pair Setup, the Pairing Identifier used for the _`kTLVType_Identifier`_ must be the accessoryʼs globally unique ID
as defined by the ”id” key in the Table 6-7 (page 58).


6.5.2 Session Security


Once the controller and accessory have established an authenticated ephemeral shared secret using Pair Verify, both
the controller and the accessory use the shared secret to derive the read and write keys for session security:

```
AccessoryToControllerKey = HKDF-SHA-512 of
  InputKey = <Pair Verify shared secret>
  Salt = ”Control-Salt”
  Info = ”Control-Read-Encryption-Key”
  OutputSize = 32 bytes

ControllerToAccessoryKey = HKDF-SHA-512 of
  InputKey = <Pair Verify shared secret>
  Salt = ”Control-Salt”
  Info = ”Control-Write-Encryption-Key”
  OutputSize = 32 bytes

```

The controller and accessory use the derived keys in the following manner:


**Table 6-9:** Derived Session Key Usage

|Col1|Format JSON String|Description|
|---|---|---|
|Accessory|AccessoryToControllerKey|ControllerToAccessoryKey|
|Controller|ControllerToAccessoryKey|AccessoryToControllerKey|



Each HTTP message must be secured with the AEAD algorithm AEAD_CHACHA20_POLY1305 as specified in Section
[2.8 of RFC 7539. The 32-bit fixed-common part of the 96-bit nonce is all zeros:](https://tools.ietf.org/html/rfc7539) _`00 00 00 00`_ .


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


59


6. HomeKit Accessory Protocol for IP Accessories


Each HTTP message is split into frames no larger than 1024 bytes. Each frame has the following format:

```
<2:AAD for little endian length of encrypted data (n) in bytes>
   <n:encrypted data according to AEAD algorithm, up to 1024 bytes>
   <16:authTag according to AEAD algorithm>

```

Once session security has been established, if the accessory encounters a decryption failure then it must immediately
close the connection used for the session.

##### 6.6 IP Accessory Attribute Database


The accessory attribute database is a list of HAP accessory objects, Service objects, and Characteristic objects serialized into JSON. As such, name/value pairs in JSON objects are unordered, and values in JSON arrays are ordered.


6.6.1 Service and Characteristic Types


[Service and Characteristic types are UUIDs as defined by RFC 4122. Apple-defined service and characteristic types](https://tools.ietf.org/html/rfc4122)
are based on the following HAP Base UUID:

```
00000000-0000-1000-8000-0026BB765291

```

When Apple-defined UUIDs are encoded as JSON strings, a short form must be used by including only the first 8
characters with leading zeros removed. When converting short form UUIDs back to full UUIDs, the process is reversed by prefixing the string with 0 or more ʼ0ʼ characters to expand it to 8 characters then ”-0000-1000-80000026BB765291” is appended to form the full 36-character UUID.


For example, the public.hap.service.accessory-information full UUID is ”0000003E-0000-1000-8000-0026BB765291”.
When encoded as a JSON string, the first 8 characters are ”0000003E” and with leading zeros removed it becomes
”3E”. Converting back to a full UUID would prefix ”3E” with six ʼ0ʼ characters to get ”0000003E” then append ”0000-1000-8000-0026BB765291” to form a full UUID of ”0000003E-0000-1000-8000-0026BB765291”. Other
examples:

```
”00000001-0000-1000-8000-0026BB765291” -> ”1”
”00000F25-0000-1000-8000-0026BB765291” -> ”F25”
”0000BBAB-0000-1000-8000-0026BB765291” -> ”BBAB”
”010004FF-0000-1000-8000-0026BB765291” -> ”10004FF”
”FF000000-0000-1000-8000-0026BB765291” -> ”FF000000”

```

[Custom service and characteristic types must be 128-bit UUIDs as defined by RFC 4122. Custom types must be](https://tools.ietf.org/html/rfc4122)
encoded as the full UUID string in JSON. Custom types must not use the HAP Base UUID.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


60


6. HomeKit Accessory Protocol for IP Accessories


6.6.2 Getting the Accessory Attribute Database


A controller obtains the attribute database by sending the accessory an HTTP GET request to _`/accessories`_ :

```
GET /accessories HTTP/1.1
Host: lights.local:12345

```

If the controller is paired with the accessory then the accessory will return the attribute database in the message body
of the HTTP response.


Controllers should cache the attribute database and monitor the current configuration number, _`c#`_ in Table 6-7 (page 58),
for changes, which indicates that the controller should get the attribute database and update its cache. Unpaired controllers must not cache the attribute database.


If an updated attribute database shows that it is missing some services and characteristics, then these service and
characteristics will be deleted from the home.


6.6.3 IP Protocol Version


IP accessories must include ”8.17 HAP Protocol Information” (page 142). For a bridge accessory, only the primary
HAP accessory object must contain ”8.17 HAP Protocol Information” (page 142). The IP protocol version is a string
with the following format: ”X.Y.Z”. Please see ”9.125 Version” (page 233) for detailed definition of the characteristic.
This must be set to ”1.1.0” for this version of HAP IP. The ”pv” Key in Bonjour TXT record (Table 6-7 (page 58)) is
truncated to ”X.Y”. It must be set to ”1.1” for this version of HAP IP.


6.6.4 Example Accessory Attribute Database in JSON


Below is an example HTTP response containing the HAP attribute database for a light bulb bridge with two light bulbs:

```
  HTTP/1.1 200 OK
  Content-Type: application/hap+json
  Content-Length: <length>

  {
     ”accessories” : [
       {
          ”aid” : 1,
          ”services” : [
            {
               ”type” : ”3E”,
               ”iid” : 1,
               ”characteristics” : [
                 {
                    ”type” : ”23”,
                    ”value” : ”Acme Light Bridge”,
                    ”perms” : [ ”pr” ],

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


61


```
},
{

},
{

},
{

},
{

},
{

},

```


6. HomeKit Accessory Protocol for IP Accessories

```
”format” : ”string”,
”iid” : 2

”type” : ”20”,
”value” : ”Acme”,
”perms” : [ ”pr” ],
”format” : ”string”,
”iid” : 3

”type” : ”30”,
”value” : ”037A2BABF19D”,
”perms” : [ ”pr” ],
”format” : ”string”,
”iid” : 4

”type” : ”21”,
”value” : ”Bridge1,1”,
”perms” : [ ”pr” ],
”format” : ”string”,
”iid” : 5

”type” : ”14”,
”value” : null,
”perms” : [ ”pw” ],
”format” : ”bool”,
”iid” : 6

”type” : ”52”,
”value” : ”100.1.1”,
”perms” : [ ”pr” ],
”format” : ”string”,
”iid” : 7

```

```
},
{

```

```
 ]

 ”type” : ”A2”,
 ”iid” : 8,
 ”characteristics” : [
   {
     ”type” : ”37”,
     ”value” : ”01.01.00”,
     ”perms” : [ ”pr” ],

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


62


```
},
{

```


6. HomeKit Accessory Protocol for IP Accessories

```
          ”format” : ”string”,
          ”iid” : 9
       }
     ]
  }
]

”aid” : 2,
”services” : [
  {
     ”type” : ”3E”,
     ”iid” : 1,
     ”characteristics” : [
       {
          ”type” : ”23”,
          ”value” : ”Acme LED Light Bulb”,
          ”perms” : [ ”pr” ],
          ”format” : ”string”,
          ”iid” : 2
       },
       {
          ”type” : ”20”,
          ”value” : ”Acme”,
          ”perms” : [ ”pr” ],
          ”format” : ”string”,
          ”iid” : 3
       },
       {
          ”type” : ”30”,
          ”value” : ”099DB48E9E28”,
          ”perms” : [ ”pr” ],
          ”format” : ”string”,
          ”iid” : 4
       },
       {
          ”type” : ”21”,
          ”value” : ”LEDBulb1,1”,
          ”perms” : [ ”pr” ],
          ”format” : ”string”,
          ”iid” : 5
       },
       {
          ”type” : ”14”,
          ”value” : null,
          ”perms” : [ ”pw” ],
          ”format” : ”bool”,
          ”iid” : 6

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


63


```
},
{

}

```


6. HomeKit Accessory Protocol for IP Accessories

```
  }
]

”type” : ”43”,
”iid” : 7,
”characteristics” : [
  {
     ”type” : ”25”,
     ”value” : true,
     ”perms” : [ ”pr”, ”pw” ],
     ”format” : ”bool”,
     ”iid” : 8
  },
  {
     ”type” : ”8”,
     ”value” : 50,
     ”perms” : [ ”pr”, ”pw” ],
     ”iid” : 9,
     ”maxValue” : 100,
     ”minStep” : 1,
     ”minValue” : 20,
     ”format” : ”int”,
     ”unit” : ”percentage”
  }
]

```

```
},
{

```

```
]

”aid” : 3,
”services” : [
  {
     ”type” : ”3E”,
     ”iid” : 1,
     ”characteristics” : [
       {
          ”type” : ”23”,
          ”value” : ”Acme LED Light Bulb”,
          ”perms” : [ ”pr” ],
          ”format” : ”string”,
          ”iid” : 2
       },
       {
          ”type” : ”20”,
          ”value” : ”Acme”,
          ”perms” : [ ”pr” ],
          ”format” : ”string”,

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


64


```
},
{

},
{

},
{

}

```


6. HomeKit Accessory Protocol for IP Accessories

```
”iid” : 3

”type” : ”30”,
”value” : ”099DB48E9E28”,
”perms” : [ ”pr” ],
”format” : ”string”,
”iid” : 4

”type” : ”21”,
”value” : ”LEDBulb1,1”,
”perms” : [ ”pr” ],
”format” : ”string”,
”iid” : 5

”type” : ”14”,
”value” : null,
”perms” : [ ”pw” ],
”format” : ”bool”,
”iid” : 6

```

```
},
{

```

```
 ]

 ”type” : ”43”,
 ”iid” : 7,
 ”characteristics” : [
   {
     ”type” : ”25”,
     ”value” : true,
     ”perms” : [ ”pr”, ”pw” ],
     ”format” : ”bool”,
     ”iid” : 8
   },
   {
     ”type” : ”8”,
     ”value” : 50,
     ”perms” : [ ”pr”, ”pw” ],
     ”iid” : 9,
     ”maxValue” : 100,
     ”minStep” : 1,
     ”minValue” : 20,
     ”format” : ”int”,
     ”unit” : ”percentage”
   }
 ]

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


65


6. HomeKit Accessory Protocol for IP Accessories

```
            }
          ]
       }
     ]
  }

##### 6.7 Controlling IP Accessories

```

6.7.1 Handling HTTP Requests


The accessory must respond to HTTP requests with an HTTP response that includes an appropriate HTTP status
code:


6.7.1.1 Successful HTTP Status Codes


   - _`200 OK`_ when the request was successfully executed and the response includes a body, e.g. after successfully
reading characteristics.


   - _`204 No Content`_ when the request was successfully executed and the response has no body, e.g. after
successfully writing characteristics.


   - _`207 Multi-Status`_ when the request was processed but was not executed (partially or completely), e.g.
when writing two characteristics, one fails or both writes fails, when writing one characteristic and the write
fails.


An accessory that can successfully process the request must return a Successful HTTP Status Code. The body of the
response may be empty, or a JSON object, depending on the specification of the request.


6.7.1.2 Client Error HTTP Status Codes


   - _`400 Bad Request`_ on HTTP client error, e.g. a malformed request.


   - _`404 Not Found`_ on an invalid HTTP URL.


   - _`422 Unprocessable Entity`_ for a well-formed request that contains invalid HTTP parameters.


6.7.1.3 Server Error Status HTTP Codes


   - _`500 Internal Server Error`_ on an accessory server error, e.g. the operation timed out.


   - _`503 Service Unavailable`_ if the accessory server is too busy to service the request, e.g. reached its
maximum number of connections.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


66


6. HomeKit Accessory Protocol for IP Accessories


6.7.1.4 HAP Status Codes


If the HTTP Status Code is a Client Error (4xx) or Server Error (5xx), then the response must include an HAP Status
Code property ( _`status`_ ) indicating the error code.


If the HTTP Status Code is _`207 Multi-Status`_, then each characteristic in the response body must include a

_`status`_ property indicating the success or failure HAP status code for each characteristic.


**Table 6-10:** HAP Status Code Property

|Property|Key|JSON Type|Description|
|---|---|---|---|
|HAP Status Code|_`status`_|number|A specific status code. See Table 6-11 (page 67) for more details<br>on the supported status codes.|



**Table 6-11:** HAP Status Codes

|Status Code|Description|
|---|---|
|0|This specifies a success for the request.|
|-70401|Request denied due to insufficient privileges.|
|-70402|Unable to perform operation with requested service or characteristic, e.g., the power to the ac-<br>cessory was turned off, or the characteristic is not inaccessible in the current state.|
|-70403|Resource is busy, try again.|
|-70404|Cannot write to read only characteristic.|
|-70405|Cannot read from a write only characteristic.|
|-70406|Notification is not supported for characteristic.|
|-70407|Out of resources to process request.|
|-70408|Operation timed out.|
|-70409|Resource does not exist.|
|-70410|Accessory received an invalid value in a write request.|
|-70411|Insufficient Authorization.|



6.7.2 Writing Characteristics


The accessory must support writing values to one or more characteristics via a single HTTP request.


To write one or more characteristic values, the controller sends an HTTP PUT request to _`/characteristics`_ . The
HTTP body is a JSON object that contains an array of Characteristic Write Request objects.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


67


6. HomeKit Accessory Protocol for IP Accessories


6.7.2.1 Characteristic Write Request Objects


Characteristic Write Request objects have the following defined properties:


**Table 6-12:** Properties of Characteristic Write Objects in JSON

|Property|Key|JSON Type|Description|
|---|---|---|---|
|Accessory Instance ID|_`aid`_|number|The instance ID of the accessory that contains the charac-<br>teristic to be written. Required.|
|Instance ID|_`iid`_|number|The instance ID of the characteristic to be written. If a pro-<br>vided instance ID is not a Characteristic object, the acces-<br>sory must respond with an ”Invalid Parameters” error. See<br>Table 6-11 (page 67). Required.|
|Value|_`value`_|_<_TYPE_>_|Optional property that contains the value to be written to the<br>characteristic.|
|Events|_`ev`_|boolean|Optional property that indicates the state of event notifica-<br>tions for the characteristic.|
|Authorization Data|_`authData`_|string|Optional property that contains a base 64 encoded string<br>of the authorization data associated with the characteristic.|
|Remote|_`remote`_|boolean|Optional property that indicates if remote access was used<br>to send the request. A value of_` true`_ indicates remote ac-<br>cess was used.|
|Response|_`r`_|boolean|Optional property that indicates whether a value is expected<br>in the response to the write operation. If no_` value`_ key is<br>specified in characteristic write object, the_` r`_ key is ignored.|



At least one of _`value`_ or _`ev`_ will be present in the characteristic write request object. All characteristics write operations
must complete with success or failure before sending a response or handling other requests. If no error occurs, the
accessory must send an HTTP response with a _`204 No Content`_ status code and an empty body.


6.7.2.2 Write a Single Characteristic


For example, to set the ”9.70 On” (page 191) characteristic, which has an instance ID of ”8”, of a ”8.23 Light Bulb”
(page 147) service on an accessory with an instance ID of ”2”, the HTTP PUT request will be:

```
PUT /characteristics HTTP/1.1
Host: lights.local:12345
Content-Type: application/hap+json
Content-Length: <length>

{
  ”characteristics” : [

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


68


6. HomeKit Accessory Protocol for IP Accessories


```
{

}

```

```
”aid” : 2,
”iid” : 8,
”value” : true

```

```
  ]
}

```

If no error occurs then the accessory must respond with a _`204 No Content`_ HTTP Status Code and an empty body.
The _`value`_ key must never be included as part of the response to a write request.

```
HTTP/1.1 204 No Content

```

Otherwise, if there is an error, then the accessory must respond with a _`207 Multi-Status`_ HTTP Status Code and
an appropriate HAP status code indicating the error. For example, if the above write request was for a characteristic
that was read-only (i.e. the value of the permissions property was only Paired Read), then the response would be the
following:

```
HTTP/1.1 207 Multi-Status
Content-Type: application/hap+json
Content-Length: <length>

{
  ”characteristics” : [
     {
       ”aid” : 2,
       ”iid” : 8,
       ”status” : -70404
     }
  ]
}

```

6.7.2.3 Writing Multiple Characteristics


To write multiple characteristics, the controller will send additional Characteristic Write Request objects to the accessory. For example, to write a Boolean value to the ”9.70 On” (page 191) characteristic of ”lightA”, which has a
characteristic instance ID of ”8” and an accessory instance ID of ”2”, and ”lightB”, which has a characteristic instance
ID of ”8” and an accessory instance ID of ”3”, the controller will send the following HTTP PUT request:

```
PUT /characteristics HTTP/1.1
Content-Type: application/hap+json
Content-Length: <length>

{
  ”characteristics” : [

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


69


6. HomeKit Accessory Protocol for IP Accessories


```
{

},
{

}

```

```
”aid” : 2,
”iid” : 8,
”value” : true

”aid” : 3,
”iid” : 8,
”value” : true

```

```
  ]
}

```

If no errors occur then the accessory must respond with a _`204 No Content`_ HTTP Status Code and an empty body.
The _`value`_ key must never be included as part of the response to a write request.

```
HTTP/1.1 204 No Content

```

If an error occurs when attempting to write any characteristics, e.g. the physical devices represented by the characteristics to be written were unreachable, the accessory must respond with a _`207 Multi-Status`_ HTTP Status Code
and each response object must contain a _`status`_ entry. Characteristics that were written successfully must have a

_`status`_ of _`0`_ and characteristics that failed to be written must have a non-zero _`status`_ entry. An example is listed
below where one write failed and one succeeded:

```
HTTP/1.1 207 Multi-Status
Content-Type: application/hap+json
Content-Length: <length>

{
  ”characteristics” : [
     {
       ”aid” : 2,
       ”iid” : 8,
       ”status” : 0
     },
     {
       ”aid” : 3,
       ”iid” : 8,
       ”status” : -70402
     }
  ]
}

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


70


6. HomeKit Accessory Protocol for IP Accessories


6.7.2.4 Timed Write Procedures


Timed Write Procedure will be used to write to characteristic that require time sensitive actions. If a characteristic
requires timed writes, the accessory must indicate that using HAP Characteristics properties.


An accessory must support timed writes to all characteristics even if the characteristic property does not require it.


Timed Write Procedure will be used to securely execute a write command within a specified TTL. The accessory starts
the TTL timer after sending the response to a Prepare Write Request. The scheduled request must be executed only
if the accessory receives an Execute Write Request before its TTL timer expires.


If the accessory receives an Execute Write Request after the TTL has expired it must ignore the request and respond
with HAP status error code -70410 (HAPIPStatusErrorCodeInvalidWrite).


If the accessory receives consecutive Prepare Write Requests in the same session, the accessory must reset the timed
write transaction with the TTL specified by the latest request.


If the accessory receives a standard write request on a characteristic which requires timed write, the accessory must
respond with HAP status error code -70410 (HAPIPStatusErrorCodeInvalidWrite).


When writing multiple characteristics, the controller will send a Prepare Write Request if any of characteristic in the
multiple characteristics Write Request requires timed write.


For example, to write a Boolean value to the ”Target Door State” characteristic of ”Door”, which has a characteristic
instance ID of ”6” and an accessory instance ID of ”2”, ”Lock Target State” characteristic which has a characteristic
instance ID of ”7” and an accessory instance ID of ”2” and the ”Lock Management Auto Security Timeout” characteristic which has a characteristic instance ID of ”8” and an accessory instance ID of ”2”, the controller will send the
following the HTTP PUT request to accessory with accessory instance ID of ”2”:

```
PUT /prepare HTTP/1.1
Host: door.local:12345
Content-Type: application/hap+json
Content-Length: <length>

{
  ”ttl” : 2500
  ”pid”: 11122333

}

```

The accessory must respond with a 200 OK HTTP Status Code and include a HAP status code indicating if timed write
procedure can be executed or not.

```
HTTP/1.1 200 OK
Content-Type: application/hap+json
Content-Length: <length>

{
  ”status” : 0

}

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


71


6. HomeKit Accessory Protocol for IP Accessories


After the controller has received the response to a prepare write request, it will send a commit write request within the
TTL milliseconds. The HTTP PUT request will be:

```
PUT /characteristics HTTP/1.1
Content-Type: application/hap+json
Content-Length: <length>

{
”characteristics”: [{
”aid” : 2,
”iid” : 6,
”value” : 1

},
{
”aid” : 2,
”iid” : 7,
”value” : 3

}
{
”aid” : 2,
”iid” : 8,
”value” : 4

}]
”pid” : 11122333

}

```

If no errors occur then the accessory must respond with a 204 No Content HTTP Status Code and an empty body.
The ”value” key must never be included as part of the response to a write request.

```
HTTP/1.1 204 No Content

```

If an error occurs when attempting to write any characteristics, the accessory must respond with a 207 Multi-Status
HTTP Status Code and each response object must contain a ”status” entry. Characteristics that were written successfully must have a ”status” of 0 and characteristics that failed to be written must have a non-zero ”status” entry.
An example is listed below where one write failed and two writes succeeded:

```
HTTP/1.1 207 Multi-Status
Content-Type: application/hap+json
Content-Length: <length>
{
”characteristics”: [{
”aid” : 2,

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


72


6. HomeKit Accessory Protocol for IP Accessories

```
”iid” : 6,
”status” : 0
},
{
”aid” : 2,
”iid” : 7,
”status” : -70402
}
{
”aid” : 2,
”iid” : 8,
”status” : 0
}]
}

```

6.7.3 Writing a Characteristic with Write Response


Write response property is used for characteristics when a read response is required for a write operation. This property is typically applicable to write control point operations. The accessory must send the write response to write
operation as part of the HTTP response using 207 Multi-Status HTTP Status code. In such a case, the controller may
not perform an explicit read request to read the result of control point write operation.


6.7.4 Reading Characteristics


The accessory must support reading values from one or more characteristics via a single HTTP request.


To read the value of a characteristic, the controller sends an HTTP GET request to _`/characteristics`_ with a query
[string that conforms to Section 3.4 of RFC 3986. The query string may have the following parameters:](https://tools.ietf.org/html/rfc3986)


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


73


6. HomeKit Accessory Protocol for IP Accessories


**Table 6-13:** HAP GET Request URL Parameters

|Parameter|Description|
|---|---|
|_`id`_|The identifiers for the characteristics to be read must be formatted as_ <__`Accessory Instance`_<br>_`ID`>__`.`<__`Characteristic Instance ID`>_, as a comma-separated list. For example, to read the<br>values of characteristics with instance ID ”4” and ”8” on an accessory with an instanceID of ”1” the<br>URL parameter would be_` id=1.4,1.8`_._` id`_ is required for all GET requests.|
|_`meta`_|Boolean value that determines whether or not the response should include metadata. If_` meta`_ is not<br>present it must be assumed to be ”0”. If_` meta`_ is ”1”, then the response must include the following<br>properties if they exist for the characteristic: ”format”, ”unit”, ”minValue”, ”maxValue”, ”minStep”,<br>and ”maxLen”.|
|_`perms`_|Boolean value that determines whether or not the response should include the permissions of the<br>characteristic. If_` perms`_ is not present it must be assumed to be ”0”.|
|_`type`_|Boolean value that determines whether or not the response should include the type of characteristic.<br>If_` type`_ is not present it must be assumed to be ”0”.|
|_`ev`_|Boolean value that determines whether or not the ”ev” property of the characteristic should be in-<br>cluded in the response. If_` ev`_ is not present it must be assumed to be ”0”.|



Each parameter will be delimited by an _`&`_ character.


6.7.4.1 Reading a Single Characteristic


An example HTTP GET request to read the value of a single characteristic with instance ID ”8”, on an accessory with
instance ID ”2”, is the following:

```
GET /characteristics?id=2.8 HTTP/1.1

```

The response must contain a Characteristic object with the value, Accessory Instance ID, and the Characteristic Instance ID. In the example below, the value of the characteristic with instance ID ”8” on the accessory with instance
ID ”2” is ʼfalseʼ:

```
HTTP/1.1 200 OK
Content-Type: application/hap+json
Content-Length: <length>

{
  ”characteristics” : [
     {
       ”aid” : 2,
       ”iid” : 8,
       ”value” : false,
     }
  ]
}

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


74


6. HomeKit Accessory Protocol for IP Accessories


6.7.4.2 Reading Multiple Characteristics


To read multiple characteristics, for example, the values of all characteristics with instance ID ”8”, across accessories
with instance IDs ”2” and ”3”, the HTTP GET request would be:

```
GET /characteristics?id=2.8,3.8 HTTP/1.1

```

If all reads succeed, the accessory must respond with a _`200 OK`_ HTTP Status Code and a JSON body. The body must
contain a JSON object with the value and instance ID of each characteristic. In the example below, the value of both
characteristics is ʼfalseʼ:

```
HTTP/1.1 200 OK
Content-Type: application/hap+json
Content-Length: <length>

{
  ”characteristics” : [
     {
       ”aid” : 2,
       ”iid” : 8,
       ”value” : false,
     },
     {
       ”aid” : 3,
       ”iid” : 8,
       ”value” : false,
     }
  ]
}

```

If an error occurs when attempting to read any characteristics, e.g. the physical devices represented by the characteristics to be read were unreachable, the accessory must respond with a _`207 Multi-Status`_ HTTP Status Code and
each characteristic object must contain a _`”status”`_ entry. Characteristics that were read successfully must have
a _`”status”`_ of _`0`_ and _`”value”`_ . Characteristics that were read unsuccessfully must contain a non-zero _`”status”`_
entry and must not contain a _`”value”`_ entry. An example is listed below where one read failed and one succeeded:

```
HTTP/1.1 207 Multi-Status
Content-Type: application/hap+json
Content-Length: <length>

{
  ”characteristics” : [
     {
       ”aid” : 2,
       ”iid” : 8,
       ”status” : 0,

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


75


6. HomeKit Accessory Protocol for IP Accessories


```
},
{

}

```

```
”value” : false

”aid” : 3,
”iid” : 8,
”status” : -70402

```

```
  ]
}

```

6.7.5 Control Point Characteristics


A control-point characteristic is a write-only characteristic used to request the accessory to perform actions such as
execute commands or perform operations. The context of the request is passed as the value of the HTTP PUT request.


The value is defined by the vendor or Apple Accessory profile.


The identify characteristic is an example of a control-point characteristic.


6.7.6 Identify Routine


The accessory must implement an _identify routine_, a means of identifying the accessory so that it can be located by
the user. For example, a light bulb accessory may implement an identify routine that flashes the light bulb three times:
_Blink the light bulb (turn on to full brightness, then off) three times for 500 ms each time_


Every identify routine may be invoked by two methods:


  - Via an Identify URL if the accessory is unpaired. To learn more, see ”6.7.7 Identify HTTP URL” (page 76).


   - Via a characteristic write to the Identify characteristic, _`public.hap.characteristic.identify`_ . To learn
more, see ”9.45 Identify” (page 180).


The accessory must implement the identify routine using both of the available methods. The identity routine should
run no longer than five seconds.


6.7.7 Identify HTTP URL


The identify URL resides at _`/identify`_ . A controller sends an HTTP POST request with an empty body to /identify
on the accessory to cause it to run its identify routine:

```
POST /identify HTTP/1.1

```

The URL is only valid if the accessory is unpaired, i.e. it has no paired controllers. If the accessory has paired controllers
then the accessory must return _`400 Bad Request`_ for any HTTP requests to the /identify URL:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


76


6. HomeKit Accessory Protocol for IP Accessories

```
HTTP/1.1 400 Bad Request
Content-Type: application/hap+json
Content-Length: <length>

{
  ”status” : -70401
}

```

Otherwise, for an unpaired accessory, it will fulfill the identify request and return a _`204 No Content`_ HTTP status
code:

```
HTTP/1.1 204 No Content

##### 6.8 Notifications

```

Notifications allow an accessory to report state changes to a controller. Notifications must be explicitly configured for
each characteristic. Network-based notifications must be coalesced by the accessory using a delay of no less than
1 second. The exception to this rule includes notifications for the following characteristics which must be delivered
immediately.


  - ”9.12 Button Event” (page 163)


  - ”9.75 Programmable Switch Event” (page 194)


Additional restrictions, based on the notification method, are described below. Accessories must strictly follow these
notification policies. Excessive or inappropriate notifications may result in the user being notified of a misbehaving
accessory and/or termination of the pairing relationship. The following describes each notification method:


6.8.1 Accessory Updates State Number Internally


This internally tracks the state number within the accessory and provides it via an explicit request from the controller,
but doesnʼt send notifications. This method avoids multicast network traffic on each state change, but is the least
responsive. This is the default unless the accessory has been configured by a controller to use a different method.


6.8.2 Accessory Sends Events to Controller


The accessory delivers notifications by sending an event message, which is an unsolicited HTTP response, over the
TCP connection established by the controller. An event message has the same format as an HTTP response, but uses
an protocol version of _`EVENT/1.0`_ . Event messages must never interrupt a response that is already being sent. A
response message must also never interrupt an event message. Either of these violations would result in the controller
receiving a corrupt message. Event messages do not receive an HTTP response from the controller. Indications shall
not be sent to the controller that changed the value of a characteristic if the change was due to a write from the
controller.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


77


6. HomeKit Accessory Protocol for IP Accessories


6.8.2.1 Event Example


An example of bidirectional communication is when a controller writes the value of a ”target” characteristic, such as the
”target temperature” of a thermostat, and wants to be notified of changes in the ”current temperature” characteristic.
The following steps outline how notifications are registered and delivered:


1. The controller registers for notifications against the ”current temperature” characteristic, which has an instance ID
of 4, on an Accessory object with an instance ID of ”1”, by sending the following request to the Accessory Server:

```
PUT /characteristics HTTP/1.1
Host: thermostat.local:12345
Content-Type: application/hap+json
Content-Length: <length>

{
  ”characteristics” : [
     {
       ”aid” : 1,
       ”iid” : 4,
       ”ev” : true
     }
  ]
}

```

2. If the characteristic supports notifications then the accessory must respond with a _`204 No Content`_ HTTP status
code and an empty body. If the characteristic does not support notifications then the accessory must respond with
an HTTP _`207 Multi-Status`_ status code and a ”status” with code -70406:

```
HTTP/1.1 207 Multi-Status
Content-Type: application/hap+json
Content-Length: <length>

{
  ”characteristics” : [
     {
       ”aid” : 1,
       ”iid” : 4,
       ”status” : -70406
     }
  ]
}

```

3. When the value of the ”current temperature” value changes, the accessory sends the following unsolicited message
to the controller:

```
EVENT/1.0 200 OK

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


78


6. HomeKit Accessory Protocol for IP Accessories

```
Content-Type: application/hap+json
Content-Length: <length>

{
  ”characteristics” : [
     {
       ”aid” : 1,
       ”iid” : 4,
       ”value” : 23.0
     }
  ]
}

```

6.8.2.2 Event Policy


   - Delivering notifications to controllers requires the controller to establish an HAP session with the accessory.


   - The notification registration state of a characteristic must not persist across sessions.


   - When a new HAP session is established the notification registration state of that controller must be ʼfalseʼ for
all characteristics provided by the accessory.


   - A write-only characteristic (i.e. the characteristic permissions only include Paired Write ”pw”) must not support
event notifications.


   - The accessory must support registering for notifications against multiple characteristics in a single request.


  - The accessory should coalesce notifications whenever possible.


   - The accessory must only deliver notifications to the controller for characteristics that the controller has registered to receive notifications against.


  - At any point the controller may deregister for event notifications against a characteristic by setting the ”ev”
key to ”false.” The accessory must stop delivering notifications for the deregistered characteristic immediately
after receiving the deregister request from the controller.

##### 6.9 HTTP URLs


This section summarizes the HTTP URLs used in HAP.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


79


6. HomeKit Accessory Protocol for IP Accessories


**Table 6-14:** HTTP URLs

|URL Path|HTTP Method|Description|
|---|---|---|
|/accessories|GET|Retrieve the accessory attribute database from the accessory.<br>Only<br>valid from paired controllers. See ”6.6 IP Accessory Attribute Database”<br>(page 60).|
|/characteristics|GET|Reads characteristic data. See ”6.7.4 Reading Characteristics” (page 73).|
|/characteristics|PUT|Writes characteristic data. See ”6.7.2 Writing Characteristics” (page 67).|
|/identify|POST|Request the accessory to run its identify routine. Only valid if the accessory<br>is unpaired. See ”6.7.7 Identify HTTP URL” (page 76).|
|/pair-setup|POST|Write a pair-setup request. See ”5.6 Pair Setup” (page 34).|
|/pair-verify|POST|Write a pair-verify request. See ”5.7 Pair Verify” (page 39).|
|/pairings|POST|Add, remove, or list pairings. See ”5.10 Add Pairing” (page 43), ”5.11 Re-<br>move Pairing” (page 44), and ”5.12 List Pairings” (page 45).|
|/prepare|PUT|Prepare Write Request. See ”6.7.2.4 Timed Write Procedures” (page 71).|
|/secure-message|POST|Used to exchange HAP PDU messages after a secure session is established.|
|/resource|POST|Request the accessory to run the resource routine (e.g a snapshot is re-<br>turned in response for an IP camera accessory). See ”11.5 Image Snapshot”<br>(page 242).|


##### 6.10 HomeKit Data Stream


This section specifies the requirements for HomeKit Data Stream (HDS). The HomeKit Data Stream protocol operates
over a reliable byte stream (TCP). The TCP port range for HDS must be >= 32768. All messages are encrypted and
authenticated; HDS uses an encryption key negotiated out-of-band.


6.10.1 Data Stream Transport Security


For each new Data Stream Transport session, both the controller and accessory shall derive the read and write transport encryption keys using the following parameters, using the key salt values negotiated during the transport setup
procedure.

```
AccessoryToControllerBulkTransferEncryptionKey = HKDF-SHA-512 of
InputKey = <Current HAP session shared secret>
Salt = <ControllerKeySalt><AccessoryKeySalt>
Info = ”HDS-Read-Encryption-Key”
OutputSize = 32 bytes

ControllerToAccessoryBulkTransferEncryptionKey = HKDF-SHA-512 of
InputKey = <Current HAP session shared secret>

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


80


6. HomeKit Accessory Protocol for IP Accessories

```
Salt = <ControllerKeySalt><AccessoryKeySalt>
Info = ”HDS-Write-Encryption-Key”
OutputSize = 32 bytes

```

Each message shall be secured with the AEAD algorithm

```
 AEAD_CHACHA20_POLY1305

```

as specified in Section 2.8 of RFC 7539.


6.10.2 Frame Format


Data sent over any HDS supports encryption. The header contains a length to indicate the number of payload bytes
and a type to indicate the structure of the payload. The type and length are authenticated, but unencrypted. The
payload is encrypted and authenticated. The auth tag is unencrypted. Frames are encrypted and authenticated using
the AEAD algorithm.

```
0 1 2 3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+---------------+-----------------------------------------------+
| Type (1) | Length (3) | 4 bytes
+---------------+-----------------------------------------------+
\ /
| Payload | <Length> bytes
/ \
+---------------------------------------------------------------+
| |
| authTag (16) | 16 bytes
| |
+---------------------------------------------------------------+

```

Type = 0x01


Length = Length of payload in bytes (big endian). The length only counts for the length of the _`payload`_ field. It does
not count the fixed-size _`type/length/authTag`_ fields. In order to improve packet latency, the length field must be
between 0 and 1,048,575 bytes.


Payload contains the header and the message described below. AuthTag is used to authenticate the message. Type,
Length, and Payload fields are authenticated.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


81


6. HomeKit Accessory Protocol for IP Accessories


6.10.3 Payload Format

```
 0 1 2 3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+---------------+
| HeaderLen | 1 byte
+---------------+-----------------------------------------------+
\ /
| Header | <HeaderLen> bytes
/ \
+---------------------------------------------------------------+
\ /
| Message | <MessageLen> bytes
/ \
+---------------------------------------------------------------+

MessageLen = ( Length - HeaderLen ) - 1

```

The payload has two parts: the header and the message. The header is a dictionary of the fields needed for describing
the message. The message is a dictionary that contains the fields particular to that event, request, or response. Data
format from ”6.10.4 Data Format” (page 84) is used to encode the header and the message individually.


6.10.3.1 Messages


There are four types of messages possible in the HomeKit Data Stream:


1. Event - a one-way message that does not require any response


2. Request - a message that requires a response or acknowledgment


3. Response - the reply to a request


4. Control - Hello message as first message for the stream


**6.10.3.1.1** **Event Messages**
An event message is a one-way message that does not require any response. It can be sent by either the accessory
or the controller.


An event message contains two required keys in the header:


**Table 6-15:** Properties of Event Messages

|Key|Type|Description|
|---|---|---|
|_`protocol`_|string|The name of the protocol that should handle this message|
|_`event`_|string|The topic of this message|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


82


6. HomeKit Accessory Protocol for IP Accessories


6.10.3.2 Request Messages


A request message is a two-way message that requires a response. It can be sent by either the accessory or the
controller.


A request message contains three required keys in the header:


**Table 6-16:** Properties of Request Messages

|Key|Type|Description|
|---|---|---|
|_`protocol`_|string|The name of the protocol that should handle this message|
|_`request`_|string|The topic of this message|
|_`id`_|int64|A unique identifier to use to match to the response|



The sender must choose an identifier that is unambiguous and helps match up the corresponding response when it is
received. Once the sender receives a response for that identifier, it may use that identifier in a later request, but it must
make sure that there are never two requests in flight that use the same identifier. It is possible for the Accessory and
Controller to independently create requests that happen to use the same identifier. This is permitted as the identifier
only has a unique meaning to its sender.


Each request has a 10-second response timeout. If the sender does not receive a response to the request within this
timeout, it shall close the Data Stream connection.


If the receiver is unable to handle the request due to resource constraints (eg, low memory), the receiver must decode
the header of the request and send a response with an _`out of resource`_ error. The receiver is not required to
inspect the message dictionary (but should still perform authentication of the entire payload).


**6.10.3.2.1** **Response Messages**
After receiving a request, the receiver must reply with a response message.


A response message contains four required keys in the header:


**Table 6-17:** Properties of Response Messages

|Key|Type|Description|
|---|---|---|
|_`protocol`_|string|The name of the protocol that should handle this message|
|_`response`_|string|The topic of this message|
|_`id`_|int64|A unique identifier to use to match to the response|
|_`status`_|int64|A status code for success or error reason|



If the response is a success, then the message can contain relevant information for that topic.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


83


6. HomeKit Accessory Protocol for IP Accessories


**6.10.3.2.2** **Hello**


The controller sends a hello request as the first message on the Data Stream. The header should use _`control`_ as the
protocol and _`hello`_ as the topic. There are no fields in the message of the request or the response.


6.10.4 Data Format


Data is encoded using a tag byte to indicate the type of object and additional info. Objects that donʼt fit entirely in the
tag byte use subequent bytes. The following table below shows the encodings for objects. Integers and floating point
values use little endian encoding. Float32 is an IEEE single precision value. Float64 is an IEEE double precision value.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


84


6. HomeKit Accessory Protocol for IP Accessories


**Table 6-18:** Properties of Data Format Table 1

|Value|Format|Description|
|---|---|---|
|0x00|invalid|Reserved to avoid common errors with zeroʼd memory.|
|0x01|boolean|True value.|
|0x02|boolean|False value.|
|0x03|n/a|Terminator for variable-item objects.|
|0x04|null|Null object.|
|0x05|UUID|<16:big endian UUID>.|
|0x06|date|<8:little endian Float64 seconds since 2001-01-01 00ԃ00ԃ00>.|
|0x07|number|Integer -1.|
|0x08-0x2E|number|Integers 0-38 (value = tag - 0x08).|
|0x02F|number|Integer 39.|
|0x30|number|8-bit signed integer. Range: -128 to 127.|
|0x31|number|16-bit, little endian, signed integer. Range: -32768 to 32767.|
|0x32|number|32-bit, little endian, signed integer, Range: -2147483648 to 2147483647.|
|0x33|number|64-bit,<br>little<br>endian,<br>signed<br>integer,<br>Range:<br>-9223372036854775807<br>to<br>9223372036854775807.|
|0x35|number|Little endian Float32.|
|0x36|number|Little endian Float64.|
|0x40-0x60|string|0-32 bytes of UTF-8 (length = tag - 0x40). Not NUL terminated.|
|0x61|string|<1:length> <n:UTF-8 bytes>. Not NUL terminated.|
|0x62|string|<2:little endian length> <n:UTF-8 bytes>. Not NUL terminated.|
|0x63|string|<4:little endian length> <n:UTF-8 bytes>. Not NUL terminated.|
|0x64|string|<8:little endian length> <n:UTF-8 bytes>. Not NUL terminated.|
|0x6F|string|<n:UTF-8 bytes>. <1ԃNUL>.|
|0x70-0x90|data|0-32 bytes of data (length = tag - 0x70).|
|0x91|data|<1:length><n:bytes>.|
|0x92|data|<2:little endian length><n:bytes>.|
|0x93|data|<4:little endian length><n:bytes>.|
|0x94|data|<8:little endian length><n:bytes>.|
|0x9F|data|[data object 1][data object 2]...[data object n]<1:terminator tag>.|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


85


6. HomeKit Accessory Protocol for IP Accessories


**Table 6-19:** Properties of Data Format Table 2

|Value|Format|Description|
|---|---|---|
|0xA0-0xCF|data|Reserved|
|0xD0-0xDE|array|0-12 items (count = tag - 0D0). <object 1><object 2>...<object n>.|
|0xDF|array|[object 1][object 2]...[object n]<1:terminator tag>.|
|0xE0-0xEE|dictionary|0-14 entries (count = tag - 0E0). <key 1><value 1><key 2><value 2>...<key n><value<br>n>.|
|0xEF|array|[key 1][value 1][key 2][value 2]...[key n][value n]<1:terminator tag>.|


##### 6.11 Testing IP Accessories


This section outlines conformance tests for accessories.


1. A service must not contain characteristics with duplicate instance IDs.


2. A service must contain at least one characteristic.


3. An accessory object must not contain services with duplicate instance IDs.


4. An accessory object must contain at least one service.


5. A bridge must not contain accessory objects with duplicate instance IDs.


6. An accessory object must contain only one accessory information service.


7. An accessory information service must have instance ID = 1.


8. A service type must be a UUID.


9. A characteristic type must be a UUID.


10. An Apple-defined characteristic type must contain all or a subset of the properties defined in ”9 Apple-defined
Characteristics” (page 158). It also must not have extra permissions.


11. An Apple-defined service type must contain all of its mandatory characteristics.


12. Instance IDs must be >= 1.


13. Instance IDs must be an integer.


14. A service must not have characteristics with duplicate characteristic types.


15. A service must not have more than 100 characteristics.


16. An accessory object must not have more than 100 services.


17. A bridge must not have more than 150 accessory objects.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


86


6. HomeKit Accessory Protocol for IP Accessories


18. Value of c# in Bonjour TXT record must be within range of [1-4294967295].


19. If characteristic properties includes a value for _`maxLen`_, the value must be not be > 256.


20. The value of the characteristic (if it supports Paired Read) must be valid according to the specified format, and
metadata, as applicable. For example, if the _`minValue`_ / _`maxValue`_ metadata are 10, and 50, then the value
should not be 60.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


87


### 7 HomeKit Accessory Protocol for Bluetooth LE Ac- cessories

##### 7.1 Overview

This chapter describes the HomeKit Accessory Protocol (HAP) for Bluetooth LE accessories. Bluetooth LE Accessories
conforming to this version are referred to as HAP-BLE 2.0 accessories. Services and characteristics supported by
accessories are represented using standard GATT.

##### 7.2 Accessory Requirements


1. Must be compatible with only one (current) protocol version of the HAP-BLE specification.


2. Must conform to Bluetooth Core Specification 4.2 at a minimum. Accessories should conform to Bluetooth 5.0
or later for future compatibility.


3. Must not allow the firmware to be downgraded.


4. Must support a timer with a minimum resolution of at least 100 milliseconds.


5. Must implement a security session idle timeout and terminate the security session (and the Bluetooth link) after
30 seconds of inactivity (i.e without any HAP Transactions).


6. Must support refresh of the security session when a controller re-pair verifies with the accessory.

##### 7.3 HAP for Bluetooth LE


7.3.1 HAP Transactions and Procedures


A HAP transaction is set of related message exchanges between the controller and the accessory that perform a single
HAP function. In HAP a request-response pair is considered a single transaction. The HAP PDUs that form a single
transaction have the same transaction ID. A transaction allows the controller to validate the receipt of all HAP requests
to the accessory by receiving an authenticated response from the accessory. The accessory can validate the sender
and targeted characteristic or service for all requests.


A connected set of transactions that achieve a particular purpose form a HAP procedure. A procedure shall be determined to be completed successfully only after all the transactions as specified in the respective procedure has
completed successfully. The iOS controller will complete all procedures in a time bound fashion in order to provide a
deterministic response to HAP clients. Any procedure that times out or fails validation of the response shall result in
the current HAP secure session being invalidated and a new session may be established by the controller. A failure
to re-establish the HAP secure session within 10 seconds must result in both the accessory and the iOS controller
dropping the Bluetooth link.


There shall be only one outstanding procedure on a characteristic at a time. Accessories should be able to support
procedures on different characteristics in parallel.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


88


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


An accessory must cancel any pending procedures when a new HAP secure session starts getting established.


7.3.2 Attribute Database Authentication


To validate the authenticity of the GATT database (i.e., types, instance IDs of services and characteristics and all
characteristic metadata descriptors) each HAP characteristic must support a signature read procedure. The signature
read response must contains the following tuple:

```
< characteristic type, service type, service instance id,
[characteristic metadata descriptors] >

```

The signature read procedure must be supported with and without a secure session. When a secure session is established the procedure is encrypted and authenticated. Without a secure session the procedure is in the clear.


After an initial pair-verify and every configuration change, an iOS controller will perform a secured read of the characteristic signature and validate the service / characteristic types, and instance IDs confirming the unsecured GATT
database. The authenticated characteristic metadata read from the signature read response is used for all HAP procedures on the characteristic.


Accessories must return characteristic metadata only via the signature read procedure and must not publish the metadata descriptors in the Bluetooth LE GATT database.


7.3.3 HAP PDU Format


The HAP PDUs have a PDU header follow by an optional PDU body. All parameters in the HAP-BLE PDU have a
little-endian format, (i.e. the least significant byte is transferred first) unless specified otherwise. HAP PDU format is
specified in Table 7-1 (page 89).


**Table 7-1:** HAP PDU Format








|PDU Header|Col2|PDU Body(Optional)|Col4|
|---|---|---|---|
|Control Field<br>(1 Byte)|PDU Fixed Params|Body Length<br>(2 Bytes)|Additional Params and Values in TLV8s<br>(1-n Bytes)|



7.3.3.1 HAP PDU Header - Control Field


The first byte in the HAP PDU header is a control field that defines how the PDU and the rest of the bytes in the PDU
are interpreted, see Table 7-2 (page 89).


**Table 7-2:** HAP PDU Header - Control Field

|Bit 7|Bit 6|Bit 5|Bit 4|Bit 3|Bit 2|Bit 1|Bit 0|
|---|---|---|---|---|---|---|---|
|X|R|R|X|X|X|X|0|



The control field bit 7 indicates the fragmentation status of the HAP-BLE PDU.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


89


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


**Table 7-3:** Control Field Bit 7 Values

|Bit 7|Description|
|---|---|
|0|First Fragment (or no fragmentation)|
|1|Continuation of fragmented PDU|



The control field bit 4 indicates instance ID size in the HAP-BLE PDU.


**Table 7-4:** Control Field Bit 4 Values

|Bit 4|Description|
|---|---|
|0|16 bit IIDs (or IID = 0)|
|1|64-bit IIDs|



The control field Bit 1-3 indicates PDU types (i.e. Request or Response). All other values in the PDU type are reserved.


**Table 7-5:** Control Field Bit 1-3 Values

|Bit 3|Bit 2|Bit 1|PDU Type|
|---|---|---|---|
|0|0|0|Request|
|0|0|1|Response|



Control field bit 0 is reserved for extending the control byte. It shall be set to 0 in this version of HAP-BLE.


**Table 7-6:** Control Field Bit 0 Values

|Bit 0|Length Extension|
|---|---|
|0|1 Byte Control Field|
|1|Reserved|



Bits 5 and 6 in the control field are reserved and shall be set to 0 in this version of the HAP-BLE specification.


7.3.3.2 HAP Request Format


The HAP Request format is shown in Table 7-7 (page 90).


**Table 7-7:** HAP-BLE Request Format














|PDU Header|Col2|Col3|Col4|PDU Body (Optional)|Col6|
|---|---|---|---|---|---|
|Control Field<br>(1 Byte)|HAP Opcode<br>(1 Byte)|TID<br>(1 Byte)|CharID / SvcID<br>(2 Bytes)|Body Length<br>(2 Bytes)|Additional Params and Value in TLV8s<br>(1-n Bytes)|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


90


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


  - HAP Opcode: The second byte in the HAP-BLE PDU Request header is the HAP Opcode field. It indicates the
opcode for the HAP Request PDU. If an accessory receives a HAP PDU with an opcode that it does not support
it shall reject the PDU and respond with a status code _`Unsupported PDU`_ as defined in Table 7-37 (page 110)
in its HAP response. The supported HAP opcodes are listed in Table 7-8 (page 91).


  - TID : Transaction Identifier is an 8 bit number identifying the transaction number of this PDU. The TID is randomly generated by the originator of the request and is used to match a request/response pair.


   - CharID / SvcID: Characteristic / Service Instance Identifier is the instance ID of the characteristic / service for a
particular request.


**Table 7-8:** HAP Opcode Description

|HAP Opcode|Description|
|---|---|
|0x01|HAP-Characteristic-Signature-Read|
|0x02|HAP-Characteristic-Write|
|0x03|HAP-Characteristic-Read|
|0x04|HAP-Characteristic-Timed-Write|
|0x05|HAP-Characteristic-Execute-Write|
|0x06|HAP-Service-Signature-Read|
|0x07|HAP-Characteristic-Configuration|
|0x08|HAP-Protocol-Configuration|



7.3.3.3 HAP Response Format


The HAP Response format is shown in Table 7-9 (page 91).


**Table 7-9:** HAP Response Format












|PDU Header|Col2|Col3|PDU Body (Optional)|Col5|
|---|---|---|---|---|
|Control Field<br>(1 Byte)|TID<br>(1 Byte)|Status<br>(1 Byte)|Body Length<br>(2 Bytes)|Additional Params and Value in TLV8s<br>(1-n Bytes)|




  - TID: The second byte in the HAP PDU Response is the transaction identifier (TID). The transaction identifier
must be set to the same value as the TID of the request.


  - Status: The status code indicating success or an appropriate reason for failure (see Table 7-37 (page 110)).


7.3.3.4 HAP PDU Body


Some HAP PDUs may include a body. The first 2 bytes of the PDU body is the length field that indicates the total
length of the PDU body. Following the length field is a list of TLV parameters that includes the value and additional
parameters associated with the respective request or response.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


91


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


All additional parameters in the request and response are encoded as individual TLV8 entries. An accessory must
parse the TLV8 entries and ignore parameters that it does not support.


The additional parameters allows for future extensibility of commands by adding new meaning on how the request or
response should be processed by the receiver.


**Table 7-10:** Additional Parameter Types Description

|Additional Parameter Types|Description|
|---|---|
|0x01|HAP-Param-Value|
|0x02|HAP-Param-Additional-Authorization-Data|
|0x03|HAP-Param-Origin (local vs remote)|
|0x04|HAP-Param-Characteristic-Type|
|0x05|HAP-Param-Characteristic-Instance-ID|
|0x06|HAP-Param-Service-Type|
|0x07|HAP-Param-Service-Instance-ID|
|0x08|HAP-Param-TTL|
|0x09|HAP-Param-Return-Response|
|0x0A|HAP-Param-HAP-Characteristic-Properties-Descriptor|
|0x0B|HAP-Param-GATT-User-Description-Descriptor|
|0x0C|HAP-Param-GATT-Presentation-Format-Descriptor|
|0x0D|HAP-Param-GATT-Valid-Range|
|0x0E|HAP-Param-HAP-Step-Value-Descriptor|
|0x0F|HAP-Param-HAP-Service-Properties|
|0x10|HAP-Param-HAP-Linked-Services|
|0x11|HAP-Param-HAP-Valid-Values-Descriptor|
|0x12|HAP-Param-HAP-Valid-Values-Range-Descriptor|



7.3.3.5 HAP PDU Fragmentation Scheme


HAP PDU fragments (excluding the first fragment) shall use the format as specified in Table 7-11 (page 93).


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


92


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


**Table 7-11:** HAP PDU Fragmentation Scheme







|PDU Header|Col2|Continuation of PDU Body|
|---|---|---|
|Control Field<br>(1 Byte)|TID<br>(1 Byte)||
|0b 1000 XXX0|0xXX|0xXX|


Only the control byte and the TID bytes shall be included in the continuation fragmentʼs PDU header. The bit 7 in
the control byte shall be set to 1 indicating a continuation of fragment. All fragments shall have bits 1-3 (Request /
Response type) set to the same value as it was in the first fragment. The TID must also be set to the same value as it
was in the first fragment. Each fragment is encrypted independently when a secure session is established and when
the characteristic requires a secure read or write.


The HAP PDU must be fragmented to fit the underlying protocols MTU size. In the case of HAP-BLE over GATT the
maximum size of a fragment shall be the GATT MTU of 512 bytes. When secure reads or writes are performed and the
HAP PDU requires fragmentation, the first HAP PDU shall have a total length of up to 496 bytes (512 - 16 byte auth
tag). Subsequent fragments can be up to 496 bytes.


Individual fragments are allowed to be less than the max fragment size and for optimal performance the fragment size
will be chosen to fit within an ATT_MTU when appropriate.


The first fragment must contain the complete PDU Header and the Body Length when the optional PDU body is
present.


7.3.4 HAP-BLE PDU Payloads


7.3.4.1 HAP-Characteristic-Signature-Read-Request


**Table 7-12:** HAP-Characteristic-Signature-Read-Request











|PDU Header|Col2|Col3|Col4|
|---|---|---|---|
|Control Field<br>(1 Byte)|HAP PDU Type<br>(1 Byte)|TID<br>(1 Byte)|Characteristics Instance ID<br>CharID (2 Bytes)|
|0b 0000 0000|0x01|0xXX|0xXXXX|


7.3.4.2 HAP-Characteristic-Signature-Read-Response


**Table 7-13:** HAP-Characteristic-Signature-Read-Response 1


















|PDU Header|Col2|Col3|PDU Body|Col5|Col6|Col7|
|---|---|---|---|---|---|---|
|Control Field<br>(1 Byte)|TID<br>(1 Byte)|Status<br>(1 Byte)|Body Length<br>(2 Bytes)|TLV<br>(Chr Type)|TLV<br>(Svc ID)|TLV<br>(SvcType)|
|0b 0000 0010|0xXX|0xXX|0xXXXX|<0x04,0x10,<br>128-bit UUID>|<0x07, 0x02,<br>16-bit SvcID>|<0x06,0x10,<br>128-bit UUID>|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


93


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


**Table 7-14:** HAP-Characteristic-Signature-Read-Response 2












|PDU Body (continued)|Col2|Col3|Col4|Col5|
|---|---|---|---|---|
|TLV<br>(HAP-Chr-Properties)|TLV (Optional)<br>(GATT-User-Description)|TLV<br>(GATT-Format)|TLV (Optional)<br>(GATT-Valid-Range)|TLV (Optional)<br>(HAP-Step-Value)|
|<0x0A, 0x02,<br>HAP-Chr-Properties>|<0x0B, 0xXX,<br>UTF-8 user description string>|<0x0C, 0x07,<br>GATT-Format>|<0x0D, 0xXX,<br>GATT-Valid-Range>|<0x0E, 0xXX,<br>HAP-Step-Value>|



7.3.4.3 HAP-Characteristic-Signature-Read-Response (with Valid Values)


**Table 7-15:** HAP-Characteristic-Signature-Read-Response (with Valid Values) 1


















|PDU Header|Col2|Col3|PDU Body|Col5|Col6|Col7|
|---|---|---|---|---|---|---|
|Control Field<br>(1 Byte)|TID<br>(1 Byte)|Status<br>(1 Byte)|Body Length<br>(2 Bytes)|TLV<br>(Chr Type)|TLV<br>(Svc ID)|TLV<br>(SvcType)|
|0b 0000 0010|0xXX|0xXX|0xXXXX|<0x08,0x10,<br>128-bit UUID>|<0x0A, 0x02,<br>16-bit SvcID>|<0x09,0x10,<br>128-bit UUID>|



**Table 7-16:** HAP-Characteristic-Signature-Read-Response (with Valid Values) 2










|PDU Body (continued)|Col2|Col3|Col4|
|---|---|---|---|
|TLV<br>(HAP-Chr-Properties)|TLV<br>(Optional Descriptors)|TLV (Optional)<br>(HAP-Valid-Values)|TLV (Optional)<br>(HAP-Valid-Values-Range)|
|<0x0A, 0x02,<br>HAP-Chr-Properties>|<...>|<0x11, 0xXX, 0xAA, 0xBB,<br>0xCC,...>|<0x12, 0xXX, 0xS1,<br>0xE1,...0xSN, 0xEN>|



7.3.4.4 HAP-Characteristic-Write-Request


**Table 7-17:** HAP-Characteristic-Write-Request















|PDU Header|Col2|Col3|Col4|PDU Body|Col6|
|---|---|---|---|---|---|
|Control Field<br>(1 Byte)|HAP PDU Type<br>(1 Byte)|TID<br>(1 Byte)|CharID<br>(2 Bytes)|Body Length<br>(2 Bytes)|TLV<br>(Char Value)|
|0b 0000 0000|0x02|0xXX|0xXXXX|0xXXXX|<0x01,0xXX,value>|


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


94


7.3.4.5 HAP-Characteristic-Write-Response


**Table 7-18:** HAP-Characteristic-Write-Response



7. HomeKit Accessory Protocol for Bluetooth LE Accessories









|PDU Header|Col2|Col3|
|---|---|---|
|Control Field<br>(1 Byte)|TID<br>(1 Byte)|Status<br>(1 Byte)|
|0b 0000 0010|0xXX|0xXX|


7.3.4.6 HAP-Characteristic-Read-Request


**Table 7-19:** HAP-Characteristic-Read-Request











|PDU Header|Col2|Col3|Col4|
|---|---|---|---|
|Control Field<br>(1 Byte)|HAP PDU Type<br>(1 Byte)|TID<br>(1 Byte)|Characteristics Instance ID<br>CharID (2 Bytes)|
|0b 0000 0000|0x03|0xXX|0xXXXX|


7.3.4.7 HAP-Characteristic-Read-Response


**Table 7-20:** HAP-Characteristic-Read-Response













|PDU Header|Col2|Col3|PDU Body|Col5|
|---|---|---|---|---|
|Control Field<br>(1 Byte)|TID<br>(1 Byte)|Status<br>(1 Byte)|Body Length<br>(2 Bytes)|TLV<br>(Char Value)|
|0b 0000 0010|0xXX|0xXX|0xXXXX|<0x01,0xXX,value>|


7.3.4.8 HAP-Characteristic-Timed-Write-Request


**Table 7-21:** HAP-Characteristic-Timed-Write-Request

















|PDU Header|Col2|Col3|Col4|PDU Body|Col6|Col7|
|---|---|---|---|---|---|---|
|Control Field<br>(1 Byte)|HAP PDU Type<br>(1 Byte)|TID<br>(1 Byte)|CharID<br>(2 Bytes)|Body Length<br>(2 Bytes)|TLV<br>(TTL*100ms)<br>(1 Byte)|TLV<br>(Char Value)|
|0b 0000 0000|0x04|0xXX|0xXXXX|0xXXXX|<0x08,0x01,<br>0xXX>|<0x01, 0xXX,<br>value>|


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


95


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


7.3.4.9 HAP-Characteristic-Timed-Write-Response


**Table 7-22:** HAP-Characteristic-Timed-Write-Response









|PDU Header|Col2|Col3|
|---|---|---|
|Control Field<br>(1 Byte)|TID<br>(1 Byte)|Status<br>(1 Byte)|
|0b 0000 0010|0xXX|0xXX|


7.3.4.10 HAP-Characteristic-Execute-Write-Request


**Table 7-23:** HAP-Characteristic-Execute-Write-Request











|PDU Header|Col2|Col3|Col4|
|---|---|---|---|
|Control Field<br>(1 Byte)|HAP PDU Type<br>(1 Byte)|TID<br>(1 Byte)|Characteristics Instance ID<br>CharID (2 Bytes)|
|0b 0000 0000|0x05|0xXX|0xXXXX|


7.3.4.11 HAP-Characteristic-Execute-Write-Response


**Table 7-24:** HAP-Characteristic-Execute-Write-Response









|PDU Header|Col2|Col3|
|---|---|---|
|Control Field<br>(1 Byte)|TID<br>(1 Byte)|Status<br>(1 Byte)|
|0b 0000 0010|0xXX|0xXX|


7.3.4.12 HAP-Service-Signature-Read-Request


**Table 7-25:** HAP-Service-Signature-Read-Request











|PDU Header|Col2|Col3|Col4|
|---|---|---|---|
|Control Field<br>(1 Byte)|HAP PDU Type<br>(1 Byte)|TID<br>(1 Byte)|Service Instance ID (SvcID)<br>(2 Bytes)|
|0b 0000 0000|0x06|0xXX|0xXXXX|


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


96


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


7.3.4.13 HAP-Service-Signature-Read-Response


**Table 7-26:** HAP-Service-Signature-Read-Response
















|PDU Header|Col2|Col3|PDU Body|Col5|Col6|
|---|---|---|---|---|---|
|Control Field<br>(1 Byte)|TID<br>(1 Byte)|Status<br>(1 Byte)|Body Length<br>(2 Bytes)|TLV<br>(Svc Properties)|TLV<br>(Linked Svc)|
|0b 0000 0010|0xXX|0xXX|0xXXXX|<0x0F,0x02,<br>0xXXXX>|<0x10,0xXX, SvcID1,<br>SvcID2, ..., SvcIDn>|



If the accessory receives an invalid (eg., 0) Service instance ID in the HAP-Service-Signature-Read-Request, it must
respond with a valid HAP-Service-Signature-Read-Response with Svc Properties set to 0 and Linked Svc (if applicable) set to 0 length.


7.3.4.14 HAP-Characteristic-Configuration-Request


**Table 7-27:** HAP-Characteristic-Configuration-Request
















|PDU Header|Col2|Col3|Col4|PDU Body|Col6|
|---|---|---|---|---|---|
|Control Field<br>(1 Byte)|HAP Opcode<br>(1 Byte)|TID<br>(1 Byte)|CharID<br>(2 Bytes)|Body length<br>(2 Bytes)|Configuration Parameters<br>Optional TLVs|
|0b 0000 0000|0x07|0xXX|0xXXXX|0xXXXX|<0x01,0x02,0x01,0x00><br><0x02,0x01,0x01>|



**Table 7-28:** Characteristic configuration parameter types

|Characteristic Configuration Parameter Type|Description|
|---|---|
|0x01|HAP-Characteristic-Configuration-Param-Properties|
|0x02|HAP-Characteristic-Configuration-Param-Broadcast-Interval|



**Table 7-29:** Characteristic configuration properties

|Bitmask|Description|
|---|---|
|0x0001|Enable/Disable Broadcast Notification|
|0x0002 - 0xFFFF|Reserved|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


97


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


**Table 7-30:** Broadcast Interval

|Value|Description|
|---|---|
|0x01|20 ms (Default)|
|0x02|1280 ms|
|0x03|2560 ms|
|0x04-0xFF|Reserved|



7.3.4.15 HAP-Characteristic-Configuration-Response


**Table 7-31:** HAP-Characteristic-Configuration-Response














|PDU Header|Col2|Col3|PDU Body|Col5|
|---|---|---|---|---|
|Control Field<br>(1 Byte)|TID<br>(1 Byte)|Status<br>(1 Byte)|Body length<br>(2 Bytes)|Configuration Parameters<br>Optional TLVs|
|0b 0000 0010|0xXX|0xXX|0xXXXX|<0x01,0x02,0x01,0x00><br><0x02,0x01,0x01>|



The accessory must include all parameters in the response even if the default Broadcast Interval is used.


7.3.4.16 HAP-Protocol-Configuration-Request


**Table 7-32:** Protocol Configuration Request Types

|Protocol Configuration Request Type|Description|
|---|---|
|0x01|Generate-Broadcast-Encryption-Key|
|0x02|Get-All-Params|
|0x03|Set-Accessory-Advertising-Identifier|



**Table 7-33:** HAP-Protocol-Configuration-Request















|PDU Header|Col2|Col3|Col4|PDU Body|Col6|
|---|---|---|---|---|---|
|Control Field<br>(1 Byte)|HAP Opcode<br>(1 Byte)|TID<br>(1 Byte)|Service Instance ID<br>SvcID (2 Bytes)|Body length<br>(2 Bytes)|Configuration Parameters<br>Optional TLVs|
|0b 0000 0000|0x08|0xXX|0xXXXX|0xXXXX|<0x01,0x00><br><0x02,0x00>|


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


98


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


7.3.4.17 HAP-Protocol-Configuration-Response


**Table 7-34:** Protocol Configuration Parameter Types

|Protocol Configuration Parameter Type|Description|
|---|---|
|0x01|HAP-Param-Current-State-Number|
|0x02|HAP-Param-Current-Config-Number|
|0x03|HAP-Param-Accessory-Advertising-Identifier|
|0x04|HAP-Param-Broadcast-Encryption-Key|



**Table 7-35:** HAP-Protocol-Configuration-Response 1
















|PDU Header|Col2|Col3|PDU Body|Col5|Col6|
|---|---|---|---|---|---|
|Control Field<br>(1 Byte)|TID<br>(1 Byte)|Status<br>(1 Byte)|Body Length<br>(2 Bytes)|TLV<br>(Optional State Number)|TLV<br>(Optional Configuration Number)|
|0b 0000 0010|0xXX|0xXX|0xXXXX|<0x01,0x02,<br>0xXX XX>|<0x02, 0x01,<br>0xXX>|



**Table 7-36:** HAP-Protocol-Configuration-Response 2






|PDU Body (continued)|Col2|
|---|---|
|Optional TLV<br>(Advertising Identifier)|Optional TLV<br>(Broadcast Encryption Key )|
|<0x03, 0x06,<br>0xXX XX XX XX XX XX>|<0x04, 0x20,<br>32-byte broadcast encryption key>|



7.3.5 HAP Procedures


7.3.5.1 HAP Characteristic Signature Read Procedure


This procedure is used to read the signature of each HAP characteristic. Each HAP characteristic must support this
procedure and return the following information:


  - Characteristic instance ID


  - Characteristic type


   - Service instance ID of the service that the characteristic belongs


  - Service Type of the service that the characteristic belongs


  - All the metadata associated with the characteristic


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


99


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


The signature read procedure must be supported with and without a secure session. When a secure session is established the procedure is encrypted and authenticated. Without a secure session the procedure is in the clear.


The ”7.4.4.3 Service Instance ID” (page 122) characteristic is not considered a HAP characteristic and does not support this procedure.


The characteristics ”5.13.1.1 Pair Setup” (page 47), ”5.13.1.2 Pair Verify” (page 47) and ”5.13.1.3 Pairing Features”
(page 47) of ”5.13.1 Pairing Service” (page 47) do not support _`Paired Read`_ and _`Paired Write`_ and only support
the ”7.3.5.1 HAP Characteristic Signature Read Procedure” (page 99) without a secure session.











**Figure 7-1:** HAP Characteristic Signature Read Procedure


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


100


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


7.3.5.2 HAP Characteristic Write Procedure







**Figure 7-2:** HAP Characteristic Write Procedure


This procedure is used to write a value to the HAP characteristic.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


101


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


7.3.5.3 HAP Characteristic Read Procedure







|Col1|roller Acce|Col3|
|---|---|---|
|`GATT Write Request Payload = {`<br>`HAP-PDU: HAP-Characteristic-Rea`<br>`Transaction ID : <TransactionID`<br>`CharacteristicID : <Characteris`<br>`}`<br>[HAP-Characteristic-Read-Request]|GATT Write Request<br>[HAP-Characteristic-Read-Request]<br>GATT Write Response<br>` d-Request`<br>`  >`<br>` ticID>`||
|`GATT Write Request Payload = {`<br>`HAP-PDU: HAP-Characteristic-Rea`<br>`Transaction ID : <TransactionID`<br>`CharacteristicID : <Characteris`<br>`}`<br>[HAP-Characteristic-Read-Request]|||
|[HAP-Characteristic-Read-Response]|GATT Read Request<br>GATT Read Response<br>[HAP-Characteristic-Read-Response]<br>`GATT R`<br>`Transa`<br>`Status`<br>`Param`<br>`}`|` ead Response Payload = {`<br>`ction ID : <TransactionID>`<br>` : <status code>`<br>` TLVs : [ Value : <value> ]`|
|[HAP-Characteristic-Read-Response]|||


**Figure 7-3:** HAP Characteristic Read Procedure


This procedure is used to read a value of the HAP characteristic.


7.3.5.4 HAP Characteristic Timed Write Procedure


The HAP characteristic timed write procedure will write to characteristic that require time sensitive actions. An example is security class characteristics (Lock Target State, Target Door State, etc.). The accessory must indicate the
characteristic requires the timed write in the HAP Characteristics Properties descriptor. An accessory must support
timed writes to all characteristics even if the characteristic property does not require it.


The HAP characteristic timed write procedure shall be used to securely execute a write command within a specified TTL. The accessory must start the TTL timer after sending the HAP-Characteristic-Timed-Write-Response. The
scheduled request shall be executed only if the accessory receives the _`HAP-Characteristic-ExecuteWrite-Request`_
before its TTL timer expires.


If the accessory receives a HAP-Characteristic-Execute-Write-Request after the TTL timer has expired it shall ignore
the request and respond with an error in the HAP-Characteristic-Execute-Write-Response.


The controller will send a HAP-Characteristic-Execute-Write-Request only after it has received a HAP-CharacteristicTimed-Write-Response within the TTL milliseconds of having issued the _`GATT-Read-Request`_ for reading the response.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


102


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


If the accessory receives another HAP procedure to the same characteristics in the middle of the timed write procedure, it shall drop the security session and disconnect the Bluetooth link.









**Figure 7-4:** HAP Characteristic Timed Write Procedure (1)


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


103


7. HomeKit Accessory Protocol for Bluetooth LE Accessories









**Figure 7-5:** HAP Characteristic Timed Write Procedure (2)


7.3.5.5 HAP Characteristic Write-with-Response Procedure


This procedure extends the HAP Characteristic Write Request Procedure by adding an additional TLV (HAP-ParamReturn-Response) to the request bodyʼs TLVs in addition to the characteristic value (HAP-Param-Value). This procedure is used when a HAP write request generates a response value. The generated response is returned in the
HAP-Characteristic-Write-Responseʼs PDUʼs body as an additional TLV (HAP-Param-Value).


Pair setup and pair verify use this procedure as illustrated in Figure 7-6 (page 105), Figure 7-7 (page 106) and Figure 78 (page 107) (Note: The underlying GATT write and read requests to deliver the HAP requests and responses are not
shown)


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


104


7. HomeKit Accessory Protocol for Bluetooth LE Accessories

|Col1|roller Acce|Col3|
|---|---|---|
|`GATT Write Request Payload =`<br>`HAP-PDU: HAP-Characteristic-`<br>`Transaction ID : <Transactio`<br>`CharacteristicID : <Characte`<br>`Param TLVs : [ Return-Respon`<br>`Value : (M1, SRP Start Reque`<br>`}`<br>[Pair Setup]<br>`GATT Write Request Payload =`<br>`HAP-PDU: HAP-Characteristic-`<br>`Transaction ID : <Transactio`<br>`CharacteristicID : <Characte`<br>`Param TLVs : [ Return-Respon`<br>`Value : (M3, SRP Verify Requ`<br>`}`|HAP-Characteristic-Write-Request<br>(With-Response)<br>HAP-Characteristic-Write-Response<br>`   {`<br>` Write-Request`<br>`  nID>`<br>` risticID>`<br>`  se : 1,`<br>`   st) ]`<br>`GATT Read Response P`<br>`Transaction ID : <Tr`<br>`Status : <status cod`<br>`Param TLVs : [ Value`<br>`}`<br>HAP-Characteristic-Write-Request<br>(With-Response)<br>`   {`<br>` Write-Request`<br>`  nID>`<br>` risticID>`<br>`  se : 1,`<br>`   est) ]`|`  ayload = {`<br>`  ansactionID>`<br>`  e>`<br>`   : (M2, SRP Start Response) ]`|
|`GATT Write Request Payload =`<br>`HAP-PDU: HAP-Characteristic-`<br>`Transaction ID : <Transactio`<br>`CharacteristicID : <Characte`<br>`Param TLVs : [ Return-Respon`<br>`Value : (M1, SRP Start Reque`<br>`}`<br>[Pair Setup]<br>`GATT Write Request Payload =`<br>`HAP-PDU: HAP-Characteristic-`<br>`Transaction ID : <Transactio`<br>`CharacteristicID : <Characte`<br>`Param TLVs : [ Return-Respon`<br>`Value : (M3, SRP Verify Requ`<br>`}`|||



**Figure 7-6:** HAP Characteristic Write-with-Response Pair Setup Procedure (1)


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


105


7. HomeKit Accessory Protocol for Bluetooth LE Accessories



|Col1|roller Acce|Col3|
|---|---|---|
|`GATT Write Request Payload =`<br>`HAP-PDU: HAP-Characteristic-`<br>`Transaction ID : <Transactio`<br>`CharacteristicID : <Characte`<br>`Param TLVs : [ Return-Respon`<br>`Value : (M5, SRP Exchange Re`<br>`}`<br>[Pair Setup]|HAP-Characteristic-Write-Request<br>(With-Response)<br>HAP-Characteristic-Write-Response<br>`   {`<br>` Write-Request`<br>`  nID>`<br>` risticID>`<br>`  se : 1,`<br>`   quest) ]`<br>`GATT Read Response Pa`<br>`Transaction ID : <Tra`<br>`Status : <status code`<br>`Param TLVs : [ Value`<br>`}`<br>`GATT Read Response Payl`<br>`Transaction ID : <Trans`<br>`Status : <status code>`<br>`Param TLVs : [ Value :`<br>`}`<br>HAP-Characteristic-Write-Response|`  yload = {`<br>`  nsactionID>`<br>`  >`<br>`   : (M4, SRP Verify Response) ]`<br>`  oad = {`<br>`  actionID>`<br>`   (M6, SRP Exchange Response) ]`|
|`GATT Write Request Payload =`<br>`HAP-PDU: HAP-Characteristic-`<br>`Transaction ID : <Transactio`<br>`CharacteristicID : <Characte`<br>`Param TLVs : [ Return-Respon`<br>`Value : (M5, SRP Exchange Re`<br>`}`<br>[Pair Setup]|||


**Figure 7-7:** HAP Characteristic Write-with-Response Pair Setup Procedure (2)


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


106


7. HomeKit Accessory Protocol for Bluetooth LE Accessories





**Figure 7-8:** HAP Characteristic Write-with-Response Pair Verify Procedure


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


107


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


7.3.5.6 HAP Fragmented Writes













**Figure 7-9:** HAP Fragmented Writes


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


108


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


7.3.5.7 HAP Fragmented Read













**Figure 7-10:** HAP Fragmented Read


7.3.5.8 HAP Characteristic Configuration Procedure


This procedure is used to enable or disable broadcast notification on each characteristic. When broadcast notification is enabled the ”7-30 Broadcast Interval” (page 98) specifies the advertisement interval to be used when the
configured characteristic change is indicated via ”7.4.6.2 Broadcasted Events” (page 128).


”7-27 HAP-Characteristic-Configuration-Request” (page 97) and ”7-31 HAP-Characteristic-Configuration-Response”
(page 98) shall be used to configure characteristics.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


109


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


7.3.5.9 HAP Protocol Configuration Procedure


This procedure is used to generate the Broadcast Encryption Key ”7.4.7.3 Broadcast Encryption Key Generation”
(page 130) and to get or set protocol specific parameters on the accessory.


”7-33 HAP-Protocol-Configuration-Request” (page 98) and ”7-35 HAP-Protocol-Configuration-Response 1” (page 99)
shall be used for protocol configuration.


For broadcast encryption key generation and usage see ”7.4.7.3 Broadcast Encryption Key Generation” (page 130)
and ”7.4.7.4 Broadcast Encryption Key expiration and refresh” (page 130)


7.3.6 HAP Status Codes


**Table 7-37:** HAP Status Codes Description

|Status Codes|Definition|Description|
|---|---|---|
|0x00|Success|The request was successful.|
|0x01|Unsupported-PDU|The request failed as the HAP PDU was not recognized or sup-<br>ported.|
|0x02|Max-Procedures|The request failed as the accessory has reached the the limit on the<br>simultaneous procedures it can handle.|
|0x03|Insufficient Authorization|Characteristic requires additional authorization data.|
|0x04|Invalid Instance ID|The HAP Requestʼs characteristic or service instance ID did not<br>match the<br>addressed characteristicʼs instance ID.|
|0x05|Insufficient Authentication|Characteristic access required a secure session to be established.|
|0x06|Invalid Request|Accessory was not able to perform the requested operation.|



7.3.7 Pair-Resume Procedure


The security session restore feature (Pair-Resume) allows accessories that can save the 256 bit shared secret and
a 64 bit session identifier from previous secure session to restore a session without any new ECC computations,
significantly speeding up the session restoration and overall re-connection time.


7.3.7.1 Accessory Requirements


1. Must support restoring sessions for at-least 8 sessions


2. Must use a Least Frequently Used or a Least Recently Used scheme to forget sessions that exceeds the maximum number of sessions that the accessory can resume.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


110


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


7.3.7.2 Defines


**Table 7-38:** Defines Description

|Define|Value|Description|
|---|---|---|
|kTLVMethod_Resume|0x06|Pair-Resume|
|kTLVType_SessionID|0x0E|Identifier to resume a session.|



7.3.7.3 Initial SessionID


After an initial pair-verify the controller and the accessory will generate an initial session ID that can be used to restore
the security session in the next Pair-Resume attempt. The _`SessionID`_ is computed by using the _`HKDF-SHA-512`_ of
the following:


_`InputKey`_ _`=`_ _<_ _`Current Session Shared Secret`_ _>_

```
 Salt = ”Pair-Verify-ResumeSessionID-Salt”

 Info = ”Pair-Verify-ResumeSessionID-Info”

 OutputSize = 8 bytes

```

7.3.7.4 Pair Resume


The initial _`SessionID`_ generated during the pair-verify can be used by the controller to resume the subsequent session. Pair-Resume is compatible with the pair-verify procedure and if the accessory does not have the previous

_`SessionID`_ stored it can fall back to normal pair-verify procedure.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


111


7. HomeKit Accessory Protocol for Bluetooth LE Accessories











**Figure 7-11:** Pair Resume Procedure(1)


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


112


7. HomeKit Accessory Protocol for Bluetooth LE Accessories



**Figure 7-12:** Pair Resume Procedure(2)


**7.3.7.4.1** **M1: Controller -> Accessory - Resume Request**


The controller performs the following steps:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


113


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


1. Generate a new and random Curve25519 key pair. This enables _<_ _`M1`_ _>_ to be usable as the first message of
pair verify if pair resume fails.


2. Derive a request encryption key, _`RequestKey`_ using the _`HKDF-SHA-512`_ of the following:


_`InputKey`_ _`=`_ _<_ _`Shared Secret from previous session`_ _>_


_`Salt`_ _`=`_ _<_ _`Controller’s new Curve25519 public key`_ _><_ _`SessionID`_ _>_

```
    Info = ”Pair-Resume-Request-Info”

    OutputSize = 32 bytes

```

3. Encrypt and generate auth-tag with an empty RequestData. This uses the ChaCha20-Poly1305 AEAD
algorithm with the following parameters:
```
   encryptedData, authTag = ChaCha20-Poly1305(RequestKey, Nonce=”PR-Msg01”,
   AAD=<none>, Msg=<0 byte RequestData>)

```

4. Send request to accessory with the following TLV items:


_`kTLVType_State`_ _<_ _`M1`_ _>_


_`kTLVType_Method`_ _<_ _`kTLVMethod_Resume`_ _>_


_`kTLVType_PublicKey`_ _<_ _`Controller’s Curve25519 public key`_ _>_


_`kTLVType_SessionID`_ _<_ _`Session ID to resume`_ _>_


_`kTLVType_EncryptedData`_ _<_ _`16 bytes of auth tag`_ _>_


*Note: The Session ID is encoded as a 8 byte little-endian integer


**7.3.7.4.2** **M2: Accessory -> Controller - Resume Response**


When the accessory receives _<_ _`M1`_ _>_, it must perform the following steps:


1. Look up the session ID in the list of saved sessions to get shared secret. If the session is not found or has
expired, the accessory must treat this as _<_ _`M1`_ _>_ of pair verify. This avoids needing another round trip to fail
and start pair verify. If the session is found and valid then continue with pair resume.


2. Invalidate session ID so it cannot be used again.


3. Derive the encryption key (same as the controller).


4. Verify authTag of encrypted data. If this fails, respond with _<_ _`M2`_ _>_ and _`kTLVError_Authentication`_ .


5. Generate new, random session ID*. This can be used for a subsequent pair resume.


*Note: The _<_ _`New Session ID`_ _>_ generated by the accessory in the pair resume must be generated randomly
and must not be in anyway derived from current or previous session information.


6. Derive a response encryption key, _`ResponseKey`_ using the _`HKDF-SHA-512`_ of the following:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


114


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


_`InputKey`_ _`=`_ _<_ _`Shared Secret from previous session`_ _>_


_`Salt`_ _`=`_ _<_ _`Controller’s Curve25519 public key`_ _><_ _`New SessionID`_ _>_

```
    Info = ”Pair-Resume-Response-Info”

    OutputSize = 32 bytes

```

*Note: The New Session ID is encoded as a 8 byte little-endian integer


7. Encrypt and generate auth-tag with an empty ResponseData. This uses the ChaCha20-Poly1305 AEAD
algorithm with the following parameters:
```
   encryptedData, authTag = ChaCha20-Poly1305(ResponseKey, Nonce=”PR-Msg02”,
   AAD=<none>, Msg=<0 byte ResponseData>)

```

8. Send response to controller with the following TLV items:


_`kTLVType_State`_ _<_ _`M2`_ _>_


_`kTLVType_Method`_ _<_ _`kTLVMethod_Resume`_ _>_


_`kTLVType_SessionID`_ _<_ _`New Session ID`_ _>_


_`kTLVType_EncryptedData`_ _<_ _`16 bytes of auth tag`_ _>_


*Note: The New Session ID is encoded as an 8 byte little-endian integer


7.3.7.5 Compute Shared Secret


After a successful pair-resume the accessory and controller derive a new shared secret for subsequent communication. The _`Shared Secret`_ is computed by using the _`HKDF-SHA-512`_ of the following:


_`InputKey`_ _`=`_ _<_ _`Shared Secret from previous session`_ _>_


_`Salt`_ _`=`_ _<_ _`Controller’s Curve25519 public key`_ _><_ _`New SessionID`_ _>_

```
 Info = ”Pair-Resume-Shared-Secret-Info”

 OutputSize = 32 bytes

```

*Note: The New Session ID is encoded as a 8 byte little-endian integer


The new shared secret is used to derive new read/write keys as specified in AEAD Algorithm with the nonce reset to
0.

##### 7.4 Bluetooth LE


7.4.1 General requirements


7.4.1.1 Accessory Role


The accessory must implement the Bluetooth LE peripheral role as specified in the Bluetooth specification.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


115


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


7.4.1.2 Bluetooth Device Address


The accessory must use a static random Bluetooth Device Address for the LE physical channel.


7.4.1.3 Advertising Channels


The accessory must advertise on all three advertising channels (37, 38, and 39) at each advertising event.


7.4.1.4 Advertising Interval


  - The accessory must advertise at a periodic interval.


  - The accessory is allowed to change the advertising interval dynamically.


   - The accessory shall not advertise while it is connected to a HomeKit controller.


  - The accessory must be able to advertise with a minimum interval of 20 ms.


  - The accessory must choose a regular advertising interval in the range of 160 ms to 2500 ms, depending on the
accessory category and its power consumption characteristics.


  - Mains powered accessories or accessories with larger battery capacity should use a shorter interval between
160 ms to 800 ms for its regular advertisements. Battery powered accessories that do not have any controllable Apple defined characteristics (such as temperature sensors, door sensors etc) are allowed to use a larger
regular advertising interval between 1250 ms and 2500 ms for enhanced battery life.


7.4.1.5 Transmission Power


The accessory should be able to transmit at the maximum output power level as allowed by the Bluetooth Core Specification. For good wireless range accessories should transmit at least at +4 dBm.


7.4.1.6 MTU Size


The accessory must support an MTU size, ATT_MTU larger than 100 bytes during the ATT Exchange MTU Request
handshake. Accessories should use an MTU size of 150 bytes or larger.


7.4.1.7 Maximum Payload Size


The maximum length of an HAP characteristic value shall be 64000 bytes, the maximum length of the Bluetooth
LE Attribute value shall be 512 bytes and accessory must support ATT prepared writes of up-to 512 bytes. HAP
characteristics that exceed 512 bytes must be fragmented as per the HAP PDU fragmentation scheme.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


116


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


7.4.1.8 Global State Number (GSN)


The Global State Number represents the state at which a required change on the accessory was last notified to the
HomeKit controller. Accessories shall maintain a 16 bit monotonically increasing GSN value. This value must have a
range of 1-65535 and wrap to 1 when it overflows. This value must persist across reboots, power cycles, etc. This
value must be reset back to 1 when factory reset or a firmware update occurs on the accessory. For more details see
”7.4.6 HAP Notifications” (page 127)


7.4.1.9 Unpaired Identify


Unpaired Identify must be allowed only if the accessory is unpaired, i.e. it has no paired controllers. During unpaired
identify, unpaired controllers must be allowed to write to ”9.45 Identify” (page 180) characteristic.


7.4.2 HAP BLE Advertisement Formats


All the bytes in the Advertisement Data are reserved and must not be used for any other purpose.


7.4.2.1 HAP BLE Regular Advertisement Format


The regular advertisement is used for broadcasting accessory presence and current state of the accessory. This
advertisement data must include the following fields:


**7.4.2.1.1** **Flags**


   - Total length of three bytes.


  - Length byte with value 0x02: one for the Flags AD type and one for the Flags value.


  - Flags AD type, 0x01, as defined by the Bluetooth Core Specification


  - The Flags value must have the LE General Discoverable Mode, bit 1, set. Since the LE General Discoverable
Mode flag is set the LE Limited Discoverable Mode must not be set, as defined by the Bluetooth Core Specification


**Table 7-39:** Flags Description

|Length|AD Type|Value|
|---|---|---|
|0x02|0x01|0bxxxxxx1x|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


117


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


**7.4.2.1.2** **Manufacturer Data**


   - Total length of 23 bytes.


  - LEN - Length byte with a value 0x16.


  - ADT - AD Type of 0xFF.


  - CoID - Company Identifier code, 0x004C (Apple, Inc.), in little endian format.


   - TY - 8 bits for Type, which shall be set to 0x06.


  - STL - 8 bits for SubType and Length, the 3 significant bits specify the HomeKit advertising format SubType and
shall be set to 1, and the remaining 5 bits is the length of the remaining bytes in the manufacturer specific data
which shall be set to the value 17.


   - SF- 8 bits for Status Flags, Bits 1-7 are reserved and shall be set to 0, Bit 0 shall reflect the value of the HAP
Pairing Status Flag.


  - 48-bit _`Device ID`_ (”5.4 Device ID” (page 31)) of the accessory.


  - ACID - 16-bit little endian unsigned Accessory Category Identifier,which indicates the category that best describes the primary function of the accessory. This must have a range of 1-65535. This must take one of the
values defined in the ”13-1 Accessory Categories” (page 252). The Category Identifier must not change except
during a firmware update.


  - GSN - 16-bit little endian unsigned Global State Number.


  - CN - 8 bits for Configuration Number, with a default starting value of 1. Accessories must increment the config
number after a firmware update. This value must have a range of 1-255 and wrap to 1 when it overflows. This
value must persist across reboots, power cycles and firmware updates.


   - CV - 8 bit little endian Compatible Version, this value shall be set to 0x02 for this version of the HAP BLE.


  - SH - 4 byte little endian Setup Hash to support enhanced setup payload information (see ” **?? ??** ” (page **??** ))


**Table 7-40:** Manufacturer Specific Data

|Length|AD Type|Company ID|Type|STL|SF|48-bit Device ID|
|---|---|---|---|---|---|---|
|0x16|0xFF|0x4C 0x00|0x06|0xXX|0x00/0x01|0xXX 0xXX 0xXX 0xXX 0xXX 0xXX|



**Table 7-41:** Manufacturer Specific Data - continued

|ACID|GSN|CN|CV|SH|
|---|---|---|---|---|
|0xXX 0xXX|0xXX 0xXX|0xXX|0x02|0xXX 0xXX 0xXX 0xXX|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


118


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


**Table 7-42:** SubType / Length

|Value|SubType|
|---|---|
|0x31|HomeKit regular advertisement|



**Table 7-43:** HAP Pairing Status Flag

|Value|Description|
|---|---|
|_`0b0`_|The accessory has been paired with a controllers.|
|_`0b1`_|The accessory has not been paired with any controllers.|



**7.4.2.1.3** **Local Name**


  - Length byte that corresponds to the total length of the local name plus the Local Name AD type.


  - Local Name AD type, 0x09 or 0x08, as defined by the Bluetooth Core Specification. The Advertisement data
shall contain either the ʼShortened Local Nameʼ or the ʼComplete Local Nameʼ If the complete local name can
be included in the Advertisement data, the AD type of 0x09 (Complete Local Name) must be used, else the
AD type of of 0x08 (Shortened Local Name) must be used with the name truncated to fit in the advertisement
data. When the advertisement includes the shortened local name the accessory should include the complete
local name in the Scan Response.


**Table 7-44:** Local Name

|Length|AD Type|Value|
|---|---|---|
|0xXX|0x08/0x09|0xXX 0xXX ... 0xXX|



7.4.2.2 HAP BLE Encrypted Notification Advertisement Format


This advertisement must only be used to notify changes in characteristic values that are configured for ”7.4.6.2 Broadcasted Events” (page 128).


The advertisement data must include the following fields:


**7.4.2.2.1** **Flags**


   - Total length of three bytes.


  - Length byte with value 0x02: one for the Flags AD type and one for the Flags value.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


119


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


  - Flags AD type, 0x01, as defined by the Bluetooth Core Specification


  - The Flags value must have the LE General Discoverable Mode, bit 1, set. Since the LE General Discoverable
Mode flag is set the LE Limited Discoverable Mode must not be set, as defined by the Bluetooth Core Specification


**Table 7-45:** Flags Description

|Length|AD Type|Value|
|---|---|---|
|0x02|0x01|0bxxxxxx1x|



**7.4.2.2.2** **Manufacturer Data**


   - Total length of 28 bytes.


  - LEN - Length byte with a value 0x1B.


  - ADT - AD Type of 0xFF.


  - CoID - Company Identifier code, 0x004C (Apple, Inc.), in little endian format.


   - TY - 8 bits for Type, which shall be set to 0x11.


  - STL - 8 bits for HomeKit SubType and Length, the 3 significant bits specify the HomeKit SubType, and the
remaining 5 bits is the length of the remaining bytes in the manufacturer specific data which shall be set to the
value 22 (i.e the lower nibble must be set to 0x16).


  - 48-bit _`Accessory Advertising Identifier`_ The 6 byte unique identifier assigned to the accessory. By
default this identifier is the same as the accessoryʼs unique pairing identifier i.e. 48-bit _`Device ID`_ (”5.4 Device ID” (page 31)) of the accessory.


  - Encrypted and Authenticated Payload


**–** GSN - 16-bit little endian unsigned Global State Number.


**–** IID - 16-bit Characteristic instance ID for the characteristic value included in this notification.


**–** Value - 8 to 64 bits little endian characteristic value. Only characteristics with fixed length formats can
be included in the broadcast notification. See ”7-51 HAP Format to BT SIG Format mapping” (page 125)
(Characteristics with format of string or data/tlv8 cannot be used in broadcast notifications) When the
characteristic value is less than 8 bytes the remaining bytes shall be set to 0.


**–** Auth Tag - 32 bit truncated AuthTag.


**Table 7-46:** Manufacturer Specific Data

|Length|AD Type|Company ID|Type|STL|48-bit Accessory Advertising Identifier|
|---|---|---|---|---|---|
|0x1B|0xFF|0x4C 0x00|0x11|0xXX|0xXX 0xXX 0xXX 0xXX 0xXX 0xXX|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


120


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


**Table 7-47:** Manufacturer Specific Data - continued (Encrypted and Authenticated Payload)

|GSN|IID|Value|Auth Tag|
|---|---|---|---|
|0xXX 0xXX|0xXX 0xXX|0xXX 0xXX 0xXX 0xXX 0xXX 0xXX 0xXX 0xXX|0xXX 0xXX 0xXX 0xXX|



**Table 7-48:** SubType / Length

|Value|SubType / Length|
|---|---|
|0x36|HomeKit encrypted notification|



7.4.3 HAP-BLE Protocol Information Service


”8.17 HAP Protocol Information” (page 142)


7.4.3.1 BLE Protocol Version Characteristic


This is a version string with the following format: ”X.Y.Z”. This must be set to ”2.2.0” for this version of HAP BLE.
Please see ”9.125 Version” (page 233) for detailed definition of the characteristic.


7.4.3.2 Service Signature Characteristic


The accessory must support ”7.4.4.5 Characteristic Descriptors included in the GATT Database” (page 123) on this
service to allow configuration of protocol features and parameters for the accessory. ”7.3.5.9 HAP Protocol Configuration Procedure” (page 110). In addtion the ”7.4.3 HAP-BLE Protocol Information Service” (page 121) must set
”Service Supports Configuration” in its ”7-49 HAP Service Properties” (page 122) to indicate support for protocol
configuration.


7.4.4 Attributes of HAP Services and Characteristics


HAP-BLE accessories must include the ”8.1 Accessory Information” (page 134) and the ”8.17 HAP Protocol Information”
(page 142) in its GATT database.


7.4.4.1 HAP Services and HAP Characteristics


Services containing the ”7.4.4.3 Service Instance ID” (page 122) and characteristics that contain the ”7.4.4.5 Characteristic Descriptors included in the GATT Database” (page 123) are defined as HAP service and HAP characteristic
respectively.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


121


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


7.4.4.2 Instance IDs


  - Every HAP service and characteristic must include an instance ID that is unique and assigned from the same
number pool.


  - The instance IDs must be maintained for the lifetime of the HAP pairing.


  - The instance IDs must have values > 0 and a maximum value of (2^16)-1, 65535.


  - ”8.1 Accessory Information” (page 134) must have an instance ID of 1.


7.4.4.3 Service Instance ID


Every HAP service must have a read-only Service instance ID characteristic ( _`SvcID`_ ) with
UUID _`E604E95D-A759-4817-87D3-AA005083A0D1`_ .


The _`SvcID`_ is read using standard GATT read request (this implies that the HAP Characteristic Read Request procedure
is not used to read the service instance ID characteristic). The value of this characteristic is a 16-bit unsigned integer
encoded as a 2 byte little endian integer. This characteristic must always be read in the clear (with and without an
established HAP secure session). (Note: _`SvcID`_ characteristic must not have its own characteristic instance ID)


7.4.4.4 HAP Service Properties


The service properties is a multi byte value where only 2 bytes shall be used in this version. The value is encoded as
a 2 byte little endian integer.


Accessories must include the ”HAP Service Properties” characteristic only if it supports non-default properties or has
linked services. Other services must not include this characteristic.


Accessories must not change its service signature once it is paired with a controller.


**Table 7-49:** HAP Service Properties

|BitMask|Description|
|---|---|
|0x0001|Primary Service|
|0x0002|Hidden Service|
|0x0004|Service Supports Configuration|



**7.4.4.4.1** **HAP Linked Services**


Accessories must include a HAP-Param-Linked-Services in its service signature read response as an array of linked
services instance IDs. When the service does not link to other services it must return an empty list with length = 0.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


122


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


7.4.4.5 Characteristic Descriptors included in the GATT Database


**7.4.4.5.1** **Bluetooth LE Characteristic Properties**


  - The Bluetooth LE characteristic properties as defined in GATT Bluetooth Core Specification must only be a
combination of the following: ʼReadʼ, ʼWriteʼ and ʼIndicateʼ. All other possible properties are not permitted.


  - All Bluetooth LE characteristics that map to a HAP characteristics must have the ʼReadʼ and ʼWriteʼ property
set to allow for read and write to the LE characteristic. Note that the Bluetooth LE Characteristic only indicates
the GATT Read / Write and Indicate operations possible on the LE characteristic, the properties associated with
the HAP characteristic is indicated by the HAP Characteristic Properties Descriptor.


  - Characteristics that support HAP Events must indicate by setting the ʼIndicateʼ properly on the LE Characteristic.


**7.4.4.5.2** **Characteristic Instance ID**


The Characteristic Instance ID is a custom characteristic descriptor with
UUID _`DC46F0FE-81D2-4616-B5D9-6ABDD796939A`_ . The accessory must expose the instance ID of each characteristic in the Characteristic Instance ID Descriptor. The value of the descriptor is a 16-bit unsigned integer encoded
as a 2 byte little endian integer. This descriptor value must support always being read in the clear (with and without a
security session).


**7.4.4.5.3** **Client Characteristic Configuration**


Characteristics supporting ”7.4.6 HAP Notifications” (page 127) must support the Client Characteristics Configuration
descriptor with the ʼIndicationʼ bit, All other configurations are reserved and shall not be used. This descriptor value
must support always being read in the clear, i.e. with or without a security session.


**7.4.4.5.4** **Service Signature Characteristic**


The HAP service should include an optional ”Service Signature” HAP characteristic with UUID 000000A5-00001000-8000-0026BB765291 that support HAP procedures for services. This Service Signature characteristic is a
HAP Characteristic with a valid characteristic instance ID descriptor. The service signature procedures is used to read
additional information pertaining to the service such as the supported properties for the service and the list of services
that the service links to. The Service Signature Characteristic on the ”7.4.3 HAP-BLE Protocol Information Service”
(page 121) is used to configure the accessory for protocol specific configurations and set protocol parameters.


7.4.4.6 Characteristic Metadata Descriptors


HAP Characteristics can include additional descriptors that describe HAP properties, description, format and valid
values for the characteristic. These descriptors are read by the controller using the HAP Characteristic Signature
Read Procedure. These descriptors must not be published in the Bluetooth LE GATT database.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


123


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


**7.4.4.6.1** **HAP Characteristic Properties**


This descriptor is used to specify HAP specific properties associated with the characteristic. This descriptor is a multi
byte value where only 2 bytes shall be used in this version. The value of this descriptor is encoded as a 2 byte little
endian integer.


**Table 7-50:** HAP Characteristic Description

|BitMask|Description|
|---|---|
|0x0001|Characteristic Supports Read|
|0x0002|Characteristic Supports Write|
|0x0004|Characteristic Supports Additional Authorization Data|
|0x0008|Characteristic Requires HAP Characteristic Timed Write Procedure|
|0x0010|Characteristics Supports Secure Reads|
|0x0020|Characteristics Supports Secure Writes|
|0x0040|Characteristic Hidden from User|
|0x0080|Characteristic Notifies Events in Connected State|
|0x0100|Characteristic Notifies Events in Disconnected State|
|0x0200|Characteristic Supports Broadcast Notify|



**7.4.4.6.2** **Characteristic User Description**


This descriptor contains a user description for the characteristic which is an UTF-8 string that is a user textual description of the characteristic.


**7.4.4.6.3** **Characteristic Presentation Format**


This descriptor is defined as per the Bluetooth SIG-defined Characteristic Presentation Format descriptor. Only the
ʼFormatʼ and ʼUnitʼ fields shall be used, the other fields shall be set according to the following rules:


  - Exponent shall be set to 0


  - Namespace shall be set to 1


   - Description shall be set to 0


BT SIG-defined Format shall be mapped to HAP Formats according to Table 7-51 (page 125) Format of characteristics
that are not defined as part of this specification shall default to the format type ”data”.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


124


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


**Table 7-51:** HAP Format to BT SIG Format mapping

|HAP Format|BT SIG Format Value|BT SIG Description|
|---|---|---|
|bool|0x01|unsigned 8-bit; 0 = false, 1 = true|
|uint8|0x04|unsigned 8-bit integer|
|uint16|0x06|unsigned 16-bit integer|
|uint32|0x08|unsigned 32-bit integer|
|uint64|0x0A|unsigned 64-bit integer|
|int|0x10|signed 32-bit integer|
|float|0x14|IEEE-754 32-bit floating point|
|string|0x19|UTF-8 string|
|data/tlv8|0x1B|Opaque structure|



BT SIG-defined Unit shall be mapped to HAP Units according to Table 7-52 (page 125)


**Table 7-52:** HAP Unit to BT SIG Unit mapping

|HAP Units|BT SIG Assigned Number|Type|
|---|---|---|
|celsius|0x272F|org.bluetooth.unit.thermodynamic_temperature.degree_celsius|
|arcdegrees|0x2763|org.bluetooth.unit.plane_angle.degree|
|percentage|0x27AD|org.bluetooth.unit.percentage|
|unitless|0x2700|org.bluetooth.unit.unitless|
|lux|0x2731|org.bluetooth.unit.illuminance.lux|
|seconds|0x2703|org.bluetooth.unit.time.second|



**7.4.4.6.4** **Minimum and Maximum Length Descriptor**


The Bluetooth SIG-defined ʼValid Rangeʼ descriptor (see _`[https://developer.bluetooth.org/gatt/descriptors/](https://developer.bluetooth.org/gatt/descriptors/)`_ )
is used to specify the Minimum Value and Maximum Value for the characteristic. The format for this descriptors value
is the same as the characteristics format, this descriptor must only be used for formats of integer types or float.


**7.4.4.6.5** **Step Value Descriptor**


This descriptor is used to specify the minimum step value of the characteristic. The format for this descriptors value
is the same as the characteristics format, this descriptor must only be used for formats of integer types or float.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


125


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


7.4.5 Additional HAP Characteristic Requirements


Characteristics which are part of a HAP Service must contain the descriptors defined in Table 7-53 (page 126) only, all
other descriptors are reserved. The descriptor values must not change while the accessory is paired with a controller.


**Table 7-53:** Bluetooth LE Characteristic Descriptors

|Type|UUID|Require|
|---|---|---|
|Characteristic Instance ID (Custom Descriptor)|DC46F0FE-81D2-4616-B5D9-6ABDD796939A|Yes|
|HAP Characteristic Properties (Custom Descriptor)|NA|Yes|
|org.bluetooth.descriptor.gatt.<br>characteristic_presentation_format|NA|Yes|
|org.bluetooth.descriptor.gatt.<br>characteristic_user_description|NA|No|
|org.bluetooth.descriptor.gatt.<br>client _characteristic_configuration|NA|No|
|org.bluetooth.descriptor.gatt.<br>valid_range|NA|No|
|Step Value (Custom Descriptor)|NA|No|
|Valid Values (Custom Descriptor)|NA|No|
|Valid Values Range (Custom Descriptor)|NA|No|



7.4.5.1 Characteristic Format Types


The format types for characteristics follow the format types defined by GATT and ”9 Apple-defined Characteristics”
(page 158).


Apple defined characteristics shall follow the format types defined for the characteristics and shall not include the
Characteristic Presentation Format Descriptor descriptors to redefine the format type. Section ”9 Apple-defined
Characteristics” (page 158) defines some characteristics as having a format type of TLV8. In these cases, the data
payload may represent one or more TLV8 values as defined by the characteristic.


7.4.5.2 Characteristic with Additional Authorization Data


Some of the characteristics defined in ”9 Apple-defined Characteristics” (page 158) supports additional authorization data by default when included as part of particular services. The characteristic and service combination that
support additional authorization data by default are ”9.118 Target Door State” (page 229) in the ”8.16 Garage Door
Opener” (page 142) and the ”9.56 Lock Target State” (page 186) in the ”8.16 Garage Door Opener” (page 142) and


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


126


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


”8.26 Lock Mechanism” (page 148). Other characteristics can also support additional authorization data. Characteristics that support additional authorization data indicates this support by having the ”7.4.4.6 Characteristic Metadata Descriptors” (page 124) descriptor with the bit set to indicate _`Characteristic Supports Additional`_

_`Authorization Data`_ as defined in Table 7-50 (page 124). An accessory with a characteristic supporting additional authorization data may not always require additional authorization data to be present. When additional authorization data is present it is included as an additional type to the TLV8 format along with the Value and Remote TLV
types.


If the accessory receives a write request without the authorization data on characteristics that currently requires it,
the accessory must return the status code _`Insufficient Authorization`_ from Table 7-37 (page 110). If the
accessory received a write request with additional authorization data when it does not require it, the accessory shall
ignore the authorization data and accept the write request.


7.4.5.3 Valid Values Descriptor


This descriptor is used to specify the valid values supported by the characteristic. This descriptor shall only be used
for Apple defined characteristics of format unit8, that support a list of defined enumeration values.


The format for this descriptor is an n-byte sequence of UINT8 in ascending order where each byte contains one of the
valid value supported by the accessory.


This descriptor shall only be used when the characteristic supports only a subset of the defined values.


7.4.5.4 Valid Values Range Descriptor


This descriptor is used to specify a range of valid values supported by the characteristic. This descriptor shall only be
used for Apple defined characteristics of format uint8 that supports a list of list of defined enumeration values.


This descriptor shall be used when it is more efficient to specify a list of valid values as a range rather than individual
values.


This descriptor can be used in conjunction with the ”Valid Values Descriptor”.


The format for this descriptor is a list of 2-byte sequences of UINT8ʼs in ascending order where the first byte is the
starting value and the second byte is the ending value of the valid values range.


This descriptor shall only be used when the characteristic supports only a subset of the defined values.


Omission of both the ”Valid Values Descriptor” and ”Valid Values Range Descriptor” implies that the characteristic
supports all the defined enumeration values for this characteristic.


7.4.6 HAP Notifications


   - Characteristics that support HAP notifications must have the ʼIndicateʼ property set on their Bluetooth LE characteristic.


  - The characteristic must support the Bluetooth SIGʼs Characteristic Client Configuration Descriptor (see Bluetooth Core Specification) to toggle Bluetooth LE indications after a secure session is established.


  - The accessory must also support the ”7.4.1.8 Global State Number (GSN)” (page 117) increment rules as described below.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


127


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


7.4.6.1 Connected Events


When a controller is connected to an accessory the controller may choose to register for Bluetooth LE indications for
some characteristics. When an update occurs on those characteristics, the accessory must send a zero-length indication to the connected controller for that characteristic. The zero-length indication must only be sent to a controller
with an established security session. The controller will then perform a HAP-secured read of the characteristic.


Indications shall not be sent to the controller that changed the value of a characteristic if the change was due to a
write from the controller.


After the first characteristic change on characteristics that are registered for Bluetooth LE indications in the current
connected state, the GSN shall also be incremented by 1 and reflected in the subsequent advertisements after the
current connection is disconnected. The GSN must increment only once for multiple characteristic changes while in
the current connected state.


7.4.6.2 Broadcasted Events


When the value associated with a characteristic that is configured for broadcast notification changes while in a disconnected state the Global State Number (GSN) must be incremented for every such change and reflected in the
Encrypted advertisement payload. The accessory must use the configured advertising interval for the characteristic
to broadcast the changed value for at least 3 seconds.


If a controller connects to the accessory before the completion of the 3 second advertising period the accessory should
abort the encrypted advertisement and continue with its regular advertisement at the regular advertising period after
the controller disconnects.


If no controller connects to the accessory within the 3 second broadcast period then the accessory must fall back
to the Disconnected Events advertisement rule with its current GSN as specified in ”7.4.6.3 Disconnected Events”
(page 128).


For additional characteristic changes before the completion of the 3 second period and before a controller connection, the GSN should be updated again and the accessory must reflect the latest changed characteristic value in its
encrypted advertisement and continue to broadcast for an additional 3 seconds from the last change.


7.4.6.3 Disconnected Events


When the value associated with a characteristic that notifies a change while in a disconnected state changes, the
Global State Number ( _`GSN`_ ) may be incremented and reflected in the Bluetooth LE advertisement data of the accessory
as specified in ”7.4.2.1 HAP BLE Regular Advertisement Format” (page 118).


The GSN should increment only once for multiple characteristic value changes while in in disconnected state until the
accessory state changes from disconnected to connected.


Disconnected events are always enabled when the characteristic supports it. Characteristics supporting disconnected
events must support ”7.4.6.1 Connected Events” (page 128) and ”7.4.6.2 Broadcasted Events” (page 128).


The accessory should use disconnected events only to reflect important state changes in the accessory that might
need to be notified to the user. For example a contact sensor state change or a current door state change indications
are good use cases for disconnected events, whereas a temperature sensor must not use disconnected events to
reflect every change in the temperature reading. After updating the _`GSN`_ as specified in Section ”7.4.2.1 HAP BLE


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


128


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


Regular Advertisement Format” (page 118) in the disconnected state the accessory must use a 20 ms advertising
interval for at least 3 seconds.


When the broadcast events are enabled for characteristic that support disconnected events the accessory shall first
follow the broadcasted events procedure and then fall back to disconnected events as specified in ”7.4.6.2 Broadcasted Events” (page 128).


7.4.7 Security


Authenticated encryption for HAP over Bluetooth LE is provided by two mechanisms: ”7.4.7.1 Pairing” (page 129) and
”7.4.7.2 Session Security” (page 129).


7.4.7.1 Pairing


Pairing establishes a bi-directional, cryptographic relationship between a controller and an accessory. ”5 Pairing”
(page 31) describes the process for pairing a controller and an accessory over GATT and features two main components:


  - Pair Setup: The process that creates a valid pairing between a controller and an accessory. This process exchanges long-term cryptographic public keys.


  - Pair Verify: The process that verifies a valid pairing and establishes a shared secret used to secure the HAP
session.


7.4.7.2 Session Security


Once the controller and accessory have an ephemeral shared secret, both the controller and the accessory use the
shared secret to derive the read and write keys for session security:

```
AccessoryToControllerKey = HKDF-SHA-512 of
  InputKey = <Pair Verify shared secret>
  Salt = ”Control-Salt”
  Info = ”Control-Read-Encryption-Key”
  OutputSize = 32 bytes

ControllerToAccessoryKey = HKDF-SHA-512 of
  InputKey = <Pair Verify shared secret>
  Salt = ”Control-Salt”
  Info = ”Control-Write-Encryption-Key”
  OutputSize = 32 bytes

```

The controller and accessory use the derived keys in the following manner:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


129


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


**Table 7-54:** Derived Key Usage

|Col1|Encryption Key|Decryption Key|
|---|---|---|
|Accessory|AccessoryToControllerKey|ControllerToAccessoryKey|
|Controller|ControllerToAccessoryKey|AccessoryToControllerKey|



[Each message is secured with the AEAD algorithm AEAD_CHACHA20_POLY1305 as specified in Section 2.8 of RFC](https://tools.ietf.org/html/rfc7539)
[7539. The 32-bit fixed-common part of the 96-bit nonce is all zeros:](https://tools.ietf.org/html/rfc7539) _`00 00 00 00`_ .


Accessories must tear down the security session after a Bluetooth LE disconnection occurs. Accessories must support
multiple iterations of Pair Verify on a single Bluetooth LE connection. For example, a controller may connect, perform
Pair Verify, and at a later time in the same connection, perform Pair Verify again. When a new Pair Verify request is
received, the accessory must tear down its security session and respond to any pending transactions with an error.


7.4.7.3 Broadcast Encryption Key Generation


When requested by paired controller with an established secure session the accessory shall derive the broadcast
encryption key using the following parameters.

```
Broadcast-Encryption-Key = HKDF-SHA-512 of
InputKey = <Current Session shared secret>
Salt = <Controller’s Ed25519 long term public key>
Info = ”Broadcast-Encryption-Key”
OutputSize = 32 bytes

```

The broadcasted advertisementʼs encrypted and authenticated payload are secured with the AEAD algorithm AEAD_CHACHA20_POLY13
[as specified in Section 2.8 of RFC 7539 with the following parameters.](https://tools.ietf.org/html/rfc7539)

```
(Encrypted-Advertisement-Payload, AuthTag) = ChaCha20-Poly1305(Broadcast-Encryption-Key, Nonce = G

```

4 byte _`AuthTag`_ appended to the encrypted advertisement payload must be the first 4 bytes of the 16 byte AuthTag
in the original order.


7.4.7.4 Broadcast Encryption Key expiration and refresh


There shall be only one broadcast encryption key in use on the accessory at any point in time. When the controller
re-generates a new broadcast encryption using the ”7.3.5.9 HAP Protocol Configuration Procedure” (page 110) the
previous key shall be discarded and only the newly generated key shall be used for further broadcast notifications.


The broadcast encryption key shall expire automatically and must be discarded by the accessory after 32,767 (2^15 1) increments in GSN after the current broadcast key was generated. The controller will normally refresh the broadcast
key to ensure that the key does not expire automatically on the accessory. The broadcast encryption key shall also
expire on firmware updates and factory reset.


Characteristic changes while in a broadcast encryption key expired state shall not use broadcasted events and must
fall back to disconnected/connected events until the controller has re-generated a new broadcast encryption key and
re-registered characteristics for broadcasted notification.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


130


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


7.4.7.5 Securing HAP PDUs


When a secure session is established all HAP PDUʼs are secured using the HAP session security. For example, if HAP
Request PDU of size _`’n’`_ is to be secured using HAP session security, the actual data received by the GATT server
must be the following:

```
<n: encrypted HAP Request PDU’s>
<16:authTag>

```

The authTag must be appended to the encrypted value and must be sent as part of the same GATT message. The
HAP server must verify and decrypt the received payload and process the HAP PDU.


7.4.8 Firmware Update Requirements


In addition to ”3.4 Firmware Updates” (page 27) the following additional requirements are applicable for Bluetooth
accessories:


  - Bluetooth LE interface must support firmware updates over Bluetooth LE.


  - Accessories supporting random static Bluetooth LE device addresses must use a new Bluetooth LE device
address after a firmware update.

##### 7.5 Testing Bluetooth LE Accessories


1. Accessory must support only the HAP-BLE 2.x advertisement format.


2. Accessory must include Accessory Information Service and Protocol Information Service with the required
mandatory characteristics.


3. The Protocol Version characteristic value in the Protocol Information Service must match the value specified
by this specification.


4. The Compatible Version (CV) in the advertisement packet must match the value specified in this specification.


5. BLE 2.0 accessories must not support HAP-BLE 1.0 procedures (read/write etc)


6. Accessory must handle malformed PDUs and fail the request.


7. Accessory must handle fragmented PDUs.


8. Accessory should be able to generate fragmented PDUs.


9. Accessory must accept new HAP procedure even if the previous procedure was not completed.


10. Accessory must support only one HAP procedure on a characteristic at any point in time.


11. Accessory should support parallel HAP procedures on different characteristics.


12. Accessory must reject GATT Read Requests on a HAP characteristic if it was not preceded by an GATT Write
Request with the same transaction ID at most 10 seconds prior.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


131


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


13. Accessory must indicate that Security Class characteristics require HAP-Characteristic-Timed-Write using the
additional HAP characteristic property.


14. Accessory must return the same transaction ID in the HAP response that was part of the HAP request.


15. Accessory must reject HAP-Characteristic-Write-Request on characteristics that require timed writes.


16. Accessory must reject HAP-Characteristic-Write/Read/Timed-Write/Execute-Write Request to characteristics
with instance ID that does not match the characteristicʼs instance ID.


17. Accessory must reject HAP-Characteristic-Execute-Write request after TTL and discard the queued HAPTimed-Write request.


18. Accessory must not allow the accessory firmware to be downgraded.


19. Accessory must support a controller refreshing the security session.


20. Accessory must maintain the idle security session for a maximum of 30 seconds. After 30 seconds of inactivity
without any HAP Transaction, the bluetooth link must be disconnected from the accessory.


21. Accessory must drop any HAP procedure continuation across security sessions (new session or refreshes).


22. Accessory must support HAP-Characteristic-Signature-Read-Request/Response for each HAP characteristic
published.


23. Accessory must support the HAP-Characteristic-Signature-Read procedure at any time after a a secure session
is established.


24. App for accessory firmware update should check and warn user of iOS version requirement on all controllers
for the selected firmware.


25. Accessory must increment the config number after a firmware update.


26. Accessory must maintain the service and characteristic instance IDs for unchanged characteristics and services
after a firmware update.


27. Accessory must not re-use an instance ID from a service or characteristic that was removed from the current
firmware update.


28. Accessory must tear down the security session when the Bluetooth LE link disconnects.


29. Accessory must support multiple iterations of pair verify on the same Bluetooth LE connection.


30. Accessories must only indicate disconnected event support on characteristic whose change may require user
attention.


31. Changes on characteristics that do not support disconnected events must not change the global state number.


32. Multiple changes to characteristic supporting disconnected events white in disconnected state or in connected
state must change state number only once.


33. Accessories must generate a new random Unique Identifier after every factory reset.


34. Accessories must not include the characteristic metadata in the GATT database.


35. Accessories must support characteristic signature read procedure with and without a secure session.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


132


7. HomeKit Accessory Protocol for Bluetooth LE Accessories


36. Accessories that include characteristic metadata must return the characteristic metadata descriptors in the
characteristic signature read response.


37. Accessories must implement a 10 second HAP procedure timeout, all HAP procedures including Pair-Verify and
Pair-Resume (with the exception of Pair-Setup) must complete within 10 seconds, if a procedure fails to complete within the procedure timeout the accessory must drop the security session and also drop the Bluetooth
link.


38. After a Bluetooth link is established the first HAP procedure must begin within 10 seconds. Accessories must
drop the Bluetooth Link if the controller fails to start a HAP procedure within 10 seconds of establishing the
Bluetooth link.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


133


### 8 Apple-defined Services

##### 8.1 Accessory Information

Every accessory must expose a single instance of the Accessory Information service with the following definition.


The values of Manufacturer, Model, Name and Serial Number must be persistent through the lifetime of the accessory.


Any other Apple-defined characteristics added to this service must only contain one or more of the following permissions: Paired Read or Notify. Custom characteristics added to this service must only contain one or more of the
following permissions: Paired Read, Notify, Broadcast, and Hidden. All other permissions are not permitted.



|Property|Value|
|---|---|
|**UUID**|0000003E-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.accessory-information|
|**Required Characteristics**|”9.40 Firmware Revision” (page 177)<br>”9.45 Identify” (page 180)<br>”9.58 Manufacturer” (page 187)<br>”9.59 Model” (page 187)<br>”9.62 Name” (page 188)<br>”9.87 Serial Number” (page 201)|
|**Optional Characteristics**|”9.2 Accessory Flags” (page 158)<br>”9.41 Hardware Revision” (page 178)|

##### 8.2 Air Purifier





This service describes an air purifier. An air purifier accessory can have additional linked services such as:


   - ”8.15 Filter Maintenance” (page 142) service(s) to describe one or more air filters.


   - ”8.3 Air Quality Sensor” (page 135) services to describe air quality sensors.


  - ”8.13 Fan” (page 140) service to describe a fan which can be independently controlled.


   - ”8.34 Slat” (page 151) service to control vents.


If ”8.13 Fan” (page 140) is included as a linked service in an air purifier accessory:


  - Changing ”9.3 Active” (page 159) characteristic on the ”8.2 Air Purifier” (page 134) must result in corresponding change to ”9.3 Active” (page 159) characteristic on the ”8.13 Fan” (page 140).


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


134


8. Apple-defined Services


  - Changing ”9.3 Active” (page 159) characteristic on the ”8.13 Fan” (page 140) from _`Inactive`_ to _`Active`_ does
not require the ”9.3 Active” (page 159) on the ”8.2 Air Purifier” (page 134) to change. This enables _`Fan Only`_
mode on air purifier.


  - Changing ”9.3 Active” (page 159) characteristic on the ”8.13 Fan” (page 140) from _`Active`_ to _`Inactive`_ must
result in the ”9.3 Active” (page 159) on the ”8.2 Air Purifier” (page 134) to change to _`Inactive`_ .


An air purifier accessory service may include ”9.81 Rotation Speed” (page 197) to control fan speed if the fan cannot
be independently controlled.


This service requires iOS 10.3 or later.






|Property|Value|
|---|---|
|**UUID**|000000BB-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.air-purifier|
|**Required Characteristics**|”9.3 Active” (page 159)<br>”9.25 Current Air Purifier State” (page 169)<br>”9.108 Target Air Purifier State” (page 221)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.81 Rotation Speed” (page 197)<br>”9.107 Swing Mode” (page 221)<br>”9.55 Lock Physical Controls” (page 185)|


##### 8.3 Air Quality Sensor

This service describes an air quality sensor. ”9.9 Air Quality” (page 161) refers to the cumulative air quality recorded
by the accessory which may be based on multiple sensors present.


This service requires iOS 9 or later and is updated in iOS 10.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


135


8. Apple-defined Services








|Property|Value|
|---|---|
|**UUID**|0000008D-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.sensor.air-quality|
|**Required Characteristics**|”9.9 Air Quality” (page 161)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.71 Ozone Density” (page 191)<br>”9.64 Nitrogen Dioxide Density” (page 189)<br>”9.106 Sulphur Dioxide Density” (page 221)<br>”9.66 PM2.5 Density” (page 190)<br>”9.72 PM10 Density” (page 192)<br>”9.126 VOC Density” (page 233)<br>”9.96 Status Active” (page 212)<br>”9.97 Status Fault” (page 212)<br>”9.100 Status Tampered” (page 214)<br>”9.99 Status Low Battery” (page 213)|


##### 8.4 Audio Stream Management

This service manages the configuration for audio input from the accessory, if applicable.


This service requires iOS 12 or later.






|Property|Value|
|---|---|
|**UUID**|00000127-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.audio-stream-management|
|**Required Characteristics**|”9.102 Supported Audio Stream Configuration” (page 215)<br>”9.86 Selected Audio Stream Configuration” (page 200)|


##### 8.5 Battery Service

This service describes a battery service.


This service requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


136


8. Apple-defined Services









|Property|Value|
|---|---|
|**UUID**|00000096-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.battery|
|**Required Characteristics**|”9.10 Battery Level” (page 162)<br>”9.19 Charging State” (page 166)<br>”9.99 Status Low Battery” (page 213)|
|**Optional Characteristics**|”9.62 Name” (page 188)|

##### 8.6 Camera RTP Stream Management

A Camera RTP Stream Management service enables the accessory to announce the audio and video codecs and
parameters it supports, and configure and control a RTP session to stream the audio/video stream to a device.


This service requires iOS 10 or later.






|Property|Value|
|---|---|
|**UUID**|00000110-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.camera-rtp-stream-management|
|**Required Characteristics**|”9.101 Streaming Status” (page 214)<br>”9.91 Selected RTP Stream Configuration” (page 204)<br>”9.92 Setup Endpoints” (page 208)<br>”9.102 Supported Audio Stream Configuration” (page 215)<br>”9.104 Supported RTP Configuration” (page 218)<br>”9.105 Supported Video Stream Configuration” (page 219)|



The supported Video/Audio Input/Output Configuration characteristics allow an IP camera accessory to describe the
supported audio/video codec and source parameters.


The Selected Stream Configuration characteristic is a control point characteristic that a controller will use to set up an
RTP session for streaming audio/video. The value written to this characteristic selects the audio/video/RTP configuration to be used for the streaming session.

##### 8.7 Carbon Dioxide Sensor


This service describes a carbon dioxide sensor.


This service requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


137


8. Apple-defined Services








|Property|Value|
|---|---|
|**UUID**|00000097-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.sensor.carbon-dioxide|
|**Required Characteristics**|”9.15 Carbon Dioxide Detected” (page 164)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.96 Status Active” (page 212)<br>”9.97 Status Fault” (page 212)<br>”9.100 Status Tampered” (page 214)<br>”9.99 Status Low Battery” (page 213)<br>”9.16 Carbon Dioxide Level” (page 165)<br>”9.17 Carbon Dioxide Peak Level” (page 165)|


##### 8.8 Carbon Monoxide Sensor

This service describes a carbon monoxide sensor.


This service requires iOS 9 or later.






|Property|Value|
|---|---|
|**UUID**|0000007F-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.sensor.carbon-monoxide|
|**Required Characteristics**|”9.18 Carbon Monoxide Detected” (page 166)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.96 Status Active” (page 212)<br>”9.97 Status Fault” (page 212)<br>”9.100 Status Tampered” (page 214)<br>”9.99 Status Low Battery” (page 213)<br>”9.13 Carbon Monoxide Level” (page 164)<br>”9.14 Carbon Monoxide Peak Level” (page 164)|


##### 8.9 Contact Sensor

This service describes a Contact Sensor.


This service requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


138


8. Apple-defined Services








|Property|Value|
|---|---|
|**UUID**|00000080-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.sensor.contact|
|**Required Characteristics**|”9.22 Contact Sensor State” (page 168)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.96 Status Active” (page 212)<br>”9.97 Status Fault” (page 212)<br>”9.100 Status Tampered” (page 214)<br>”9.99 Status Low Battery” (page 213)|


##### 8.10 Data Stream Transport Management

The Data Stream Transport Management service enables the configuration and management of the transport data
stream. The version field must be set to “1.0”.


This service requires iOS 12 or later.



|Property|Value|
|---|---|
|**UUID**|00000129-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.data-stream-transport-management|
|**Required Characteristics**|”9.90 Setup Data Stream Transport” (page 202)<br>”9.103 Supported Data Stream Transport Configuration” (page 217)<br>”9.125 Version” (page 233)|

##### 8.11 Door





This service describes a motorized door.


This service requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


139


8. Apple-defined Services





|Property|Value|
|---|---|
|**UUID**|00000081-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.door|
|**Required Characteristics**|”9.27 Current Position” (page 170)<br>”9.117 Target Position” (page 229)<br>”9.73 Position State” (page 192)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.43 Hold Position” (page 179)<br>”9.65 Obstruction Detected” (page 189)|

##### 8.12 Doorbell





The Doorbell service describes a doorbell and is the primary service of the Video Doorbell Profile.


This service requires iOS 10 or later.



|Property|Value|
|---|---|
|**UUID**|00000121-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.doorbell|
|**Required Characteristics**|”9.75 Programmable Switch Event” (page 194)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.127 Volume” (page 234)<br>”9.11 Brightness” (page 162)|

##### 8.13 Fan

This service describes a fan.





If the fan service is included in air purifier accessories, ”9.31 Current Fan State” (page 173) and ”9.109 Target Fan
State” (page 222) are required characteristics.


This service requires iOS 10.3 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


140


8. Apple-defined Services





|Property|Value|
|---|---|
|**UUID**|000000B7-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.fanv2|
|**Required Characteristics**|”9.3 Active” (page 159)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.31 Current Fan State” (page 173)<br>”9.109 Target Fan State” (page 222)<br>”9.80 Rotation Direction” (page 196)<br>”9.81 Rotation Speed” (page 197)<br>”9.107 Swing Mode” (page 221)<br>”9.55 Lock Physical Controls” (page 185)|

##### 8.14 Faucet





This service describes accessories like faucets or shower heads. This service must only be included when an accessory has either a linked ”8.18 Heater Cooler” (page 143) with single linked ”8.43 Valve” (page 155) service or multiple
linked ”8.43 Valve” (page 155) services (with/without ”8.18 Heater Cooler” (page 143) service) to describe water
outlets. This service serves as a top level service for such accessories.


A faucet which supports heating of water must include ”8.18 Heater Cooler” (page 143) and ”8.43 Valve” (page 155)
service as linked services. An accessory which supports one or multiple water outlets and heating of water through a
common temperature control, must include ”8.18 Heater Cooler” (page 143) and ”8.43 Valve” (page 155) service(s)
as linked services to the faucet service.


Setting the value of ”9.3 Active” (page 159) to _`InActive`_ on this service must turn off the faucet accessory. The
accessory must retain the state of ”9.3 Active” (page 159) characteristics on any linked ”8.43 Valve” (page 155)
services when the ”9.3 Active” (page 159) on this service is toggled. The accessory must set the value of ”9.3 Active”
(page 159) to _`InActive`_ of any linked ”8.18 Heater Cooler” (page 143) service when the ”9.3 Active” (page 159) on
this service is set to _`InActive`_ .


This service requires iOS 11.2 or later.





|Property|Value|
|---|---|
|**UUID**|000000D7-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.faucet|
|**Required Characteristics**|”9.3 Active” (page 159)|
|**Optional Characteristics**|”9.97 Status Fault” (page 212)<br>”9.62 Name” (page 188)|


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


141


8. Apple-defined Services


##### 8.15 Filter Maintenance

This service can be used to describe maintenance operations for a filter.


This service requires iOS 10.3 or later.






|Property|Value|
|---|---|
|**UUID**|000000BA-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.filter-maintenance|
|**Required Characteristics**|”9.39 Filter Change Indication” (page 176)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.38 Filter Life Level” (page 176)<br>”9.79 Reset Filter Indication” (page 196)|


##### 8.16 Garage Door Opener

This service describes a garage door opener that controls a single door. If a garage has more than one door, then each
door should have its own Garage Door Opener Service.






|Property|Value|
|---|---|
|**UUID**|00000041-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.garage-door-opener|
|**Required Characteristics**|”9.30 Current Door State” (page 172)<br>”9.118 Target Door State” (page 229)<br>”9.65 Obstruction Detected” (page 189)|
|**Optional Characteristics**|”9.52 Lock Current State” (page 183)<br>”9.56 Lock Target State” (page 186)<br>”9.62 Name” (page 188)|


##### 8.17 HAP Protocol Information

Every accessory must expose a single instance of the HAP protocol information. For a bridge accessory, only the primary HAP accessory object must contain this service. The ”9.125 Version” (page 233) value is transport dependent.
Refer to ”7.4.3.1 BLE Protocol Version Characteristic” (page 121) for BLE protocol version. Refer to ”6.6.3 IP Protocol
Version” (page 61) for IP protocol version.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


142


8. Apple-defined Services

|Property|Value|
|---|---|
|**UUID**|000000A2-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.protocol.information.service|
|**Required Characteristics**|”9.125 Version” (page 233)|


##### 8.18 Heater Cooler


This service can be used to describe either of the following:


  - a heater


  - a cooler


  - a heater and a cooler


A heater/cooler accessory may have additional:


  - ”8.13 Fan” (page 140) service to describe a fan which can be independently controlled


  - ”8.34 Slat” (page 151) service to control vents


A heater must include ”9.42 Heating Threshold Temperature” (page 178). A cooler must include ”9.20 Cooling
Threshold Temperature” (page 167).


A heater/cooler accessory service may include ”9.81 Rotation Speed” (page 197) to control fan speed if the fan cannot
be independently controlled.


This service requires iOS 10.3 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


143


8. Apple-defined Services








|Property|Value|
|---|---|
|**UUID**|000000BC-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.heater-cooler|
|**Required Characteristics**|”9.3 Active” (page 159)<br>”9.35 Current Temperature” (page 175)<br>”9.33 Current Heater Cooler State” (page 174)<br>”9.111 Target Heater Cooler State” (page 223)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.81 Rotation Speed” (page 197)<br>”9.122 Temperature Display Units” (page 231)<br>”9.107 Swing Mode” (page 221)<br>”9.20 Cooling Threshold Temperature” (page 167)<br>”9.42 Heating Threshold Temperature” (page 178)<br>”9.55 Lock Physical Controls” (page 185)|


##### 8.19 Humidifier Dehumidifier

This service can be used to describe either of the following:


   - an air humidifier


  - an air dehumidifier


   - an air humidifier and an air dehumidifier


An air humidifier/dehumidifier accessory may have additional:


  - ”8.13 Fan” (page 140) service to describe a fan which can be independently controlled


  - ”8.34 Slat” (page 151) service to control vents


A dehumidifier must include ”9.76 Relative Humidity Dehumidifier Threshold” (page 194). A humidifier must include
”9.77 Relative Humidity Humidifier Threshold” (page 195).


A humidifier/dehumidifier accessory service may include ”9.81 Rotation Speed” (page 197) to control fan speed if the
fan cannot be independently controlled.


This service requires iOS 10.3 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


144


8. Apple-defined Services








|Property|Value|
|---|---|
|**UUID**|000000BD-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.humidifier-dehumidifier|
|**Required Characteristics**|”9.3 Active” (page 159)<br>”9.34 Current Relative Humidity” (page 174)<br>”9.29 Current Humidifier Dehumidifier State” (page 171)<br>”9.116 Target Humidifier Dehumidifier State” (page 228)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.76 Relative Humidity Dehumidifier Threshold” (page 194)<br>”9.77 Relative Humidity Humidifier Threshold” (page 195)<br>”9.81 Rotation Speed” (page 197)<br>”9.107 Swing Mode” (page 221)<br>”9.128 Water Level” (page 234)<br>”9.55 Lock Physical Controls” (page 185)|


##### 8.20 Humidity Sensor

This service describes a humidity sensor.


This service requires iOS 9 or later.






|Property|Value|
|---|---|
|**UUID**|00000082-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.sensor.humidity|
|**Required Characteristics**|”9.34 Current Relative Humidity” (page 174)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.96 Status Active” (page 212)<br>”9.97 Status Fault” (page 212)<br>”9.100 Status Tampered” (page 214)<br>”9.99 Status Low Battery” (page 213)|


##### 8.21 Irrigation System

This service describes an irrigation system. This service must be present on an irrigation systems which supports
on-device schedules or supports a top-level ”9.3 Active” (page 159) control across multiple valves.


A sprinkler system accessory may be:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


145


8. Apple-defined Services


  - a combination of ”8.21 Irrigation System” (page 145) service on a bridge accessory with a collection of one or
more ”8.43 Valve” (page 155) services (with ”9.124 Valve Type” (page 232) set to _`Irrigation`_ ) as bridged
accessories (The bridge accessory is typically connected to each valve using wires). OR


   - a combination of ”8.21 Irrigation System” (page 145) service with a collection of one or more linked ”8.43 Valve”

(page 155) services (with ”9.124 Valve Type” (page 232) set to _`Irrigation`_ ) (The valves are collocated e.g.
hose based system). OR


  - a combination of ”8.43 Valve” (page 155) service(s) with ”9.124 Valve Type” (page 232) set to _`Irrigation`_
(e.g., a system with one or more valves which does not support scheduling)


An irrigation system is set to _`Active`_ when the system is enabled. When one of the valves is set to _`In Use`_, the
irrigation system must be set to in use.


An accessory which includes this service must include the ”9.112 Set Duration” (page 223) in the ”8.43 Valve”
(page 155).


An irrigation system accessory which does not auto detect the number of valves it is connected to and requires user
to provide this information must include the ”9.49 Is Configured” (page 182) in the ”8.43 Valve” (page 155).


”9.78 Remaining Duration” (page 195) on this service implies the total remaining duration to water across all the valves.


This service requires iOS 11.2 or later.






|Property|Value|
|---|---|
|**UUID**|000000CF-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.irrigation-system|
|**Required Characteristics**|”9.3 Active” (page 159)<br>”9.74 Program Mode” (page 193)<br>”9.48 In Use” (page 181)|
|**Optional Characteristics**|”9.78 Remaining Duration” (page 195)<br>”9.62 Name” (page 188)<br>”9.97 Status Fault” (page 212)|


##### 8.22 Leak Sensor

This service describes a leak sensor.


This service requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


146


8. Apple-defined Services








|Property|Value|
|---|---|
|**UUID**|00000083-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.sensor.leak|
|**Required Characteristics**|”9.50 Leak Detected” (page 183)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.96 Status Active” (page 212)<br>”9.97 Status Fault” (page 212)<br>”9.100 Status Tampered” (page 214)<br>”9.99 Status Low Battery” (page 213)|


##### 8.23 Light Bulb

This service describes a light bulb.






|Property|Value|
|---|---|
|**UUID**|00000043-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.lightbulb|
|**Required Characteristics**|”9.70 On” (page 191)|
|**Optional Characteristics**|”9.11 Brightness” (page 162)<br>”9.44 Hue” (page 179)<br>”9.62 Name” (page 188)<br>”9.82 Saturation” (page 197)<br>”9.21 Color Temperature” (page 167)|


##### 8.24 Light Sensor

This service describes a light sensor.


This service requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


147


8. Apple-defined Services








|Property|Value|
|---|---|
|**UUID**|00000084-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.sensor.light|
|**Required Characteristics**|”9.23 Current Ambient Light Level” (page 168)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.96 Status Active” (page 212)<br>”9.97 Status Fault” (page 212)<br>”9.99 Status Low Battery” (page 213)<br>”9.100 Status Tampered” (page 214)|


##### 8.25 Lock Management

The HomeKit Lock Management Service is designed to expose deeper interaction with a Lock device.






|Property|Value|
|---|---|
|**UUID**|00000044-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.lock-management|
|**Required Characteristics**|”9.51 Lock Control Point” (page 183)<br>”9.125 Version” (page 233)|
|**Optional Characteristics**|”9.57 Logs” (page 186)<br>”9.6 Audio Feedback” (page 160)<br>”9.54 Lock Management Auto Security Timeout” (page 185)<br>”9.5 Administrator Only Access” (page 160)<br>”9.53 Lock Last Known Action” (page 184)<br>”9.30 Current Door State” (page 172)<br>”9.60 Motion Detected” (page 187)|


##### 8.26 Lock Mechanism

The HomeKit Lock Mechanism Service is designed to expose and control the physical lock mechanism on a device.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


148


8. Apple-defined Services









|Property|Value|
|---|---|
|**UUID**|00000045-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.lock-mechanism|
|**Required Characteristics**|”9.52 Lock Current State” (page 183)<br>”9.56 Lock Target State” (page 186)|
|**Optional Characteristics**|”9.62 Name” (page 188)|

##### 8.27 Microphone

A Microphone service is used to control the sourcing of the input audio – primarily through a microphone.


This service requires iOS 10 or later.






|Property|Value|
|---|---|
|**UUID**|00000112-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.microphone|
|**Required Characteristics**|”9.61 Mute” (page 188)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.127 Volume” (page 234)|


##### 8.28 Motion Sensor

This service describes a motion sensor.


This service requires iOS 9 or later.





|Property|Value|
|---|---|
|**UUID**|00000085-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.sensor.motion|
|**Required Characteristics**|”9.60 Motion Detected” (page 187)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.96 Status Active” (page 212)<br>”9.97 Status Fault” (page 212)<br>”9.100 Status Tampered” (page 214)<br>”9.99 Status Low Battery” (page 213)|


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


149


8. Apple-defined Services


##### 8.29 Occupancy Sensor

This service describes an occupancy sensor.


This service requires iOS 9 or later.



|Property|Value|
|---|---|
|**UUID**|00000086-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.sensor.occupancy|
|**Required Characteristics**|”9.67 Occupancy Detected” (page 190)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.96 Status Active” (page 212)<br>”9.97 Status Fault” (page 212)<br>”9.100 Status Tampered” (page 214)<br>”9.99 Status Low Battery” (page 213)|

##### 8.30 Outlet





This service describes a power outlet.







|Property|Value|
|---|---|
|**UUID**|00000047-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.outlet|
|**Required Characteristics**|”9.70 On” (page 191)<br>”9.69 Outlet In Use” (page 191)|
|**Optional Characteristics**|”9.62 Name” (page 188)|

##### 8.31 Security System

This service describes a security system service.


This service requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


150


8. Apple-defined Services








|Property|Value|
|---|---|
|**UUID**|0000007E-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.security-system|
|**Required Characteristics**|”9.84 Security System Current State” (page 198)<br>”9.85 Security System Target State” (page 199)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.83 Security System Alarm Type” (page 198)<br>”9.97 Status Fault” (page 212)<br>”9.100 Status Tampered” (page 214)|


##### 8.32 Service Label

This service describes label scheme.


This service requires iOS 10.3 or later.

|Property|Value|
|---|---|
|**UUID**|000000CC-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.service-label|
|**Required Characteristics**|”9.89 Service Label Namespace” (page 202)|


##### 8.33 Siri


This service allows configuration and management of Siri.


This service must be linked to the ”8.4 Audio Stream Management” (page 136) and ”8.10 Data Stream Transport
Management” (page 139). This service requires iOS 12 or later.

|Property|Value|
|---|---|
|**UUID**|00000133-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.siri|
|**Required Characteristics**|”9.93 Siri Input Type” (page 210)|


##### 8.34 Slat


This service describes a slat which tilts on a vertical or a horizontal axis. ”9.36 Current Tilt Angle” (page 175) and
”9.110 Target Tilt Angle” (page 222) may be included in this service if the user can set the slats to a particular tilt
angle.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


151


8. Apple-defined Services


”9.107 Swing Mode” (page 221) implies that the slats can swing automatically (e.g. vents on a fan).


This service requires iOS 10.3 or later.






|Property|Value|
|---|---|
|**UUID**|000000B9-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.vertical-slat|
|**Required Characteristics**|”9.26 Current Slat State” (page 170)<br>”9.94 Slat Type” (page 211)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.107 Swing Mode” (page 221)<br>”9.36 Current Tilt Angle” (page 175)<br>”9.110 Target Tilt Angle” (page 222)|


##### 8.35 Smoke Sensor

This service describes a Smoke detector Sensor.


This service requires iOS 9 or later.



|Property|Value|
|---|---|
|**UUID**|00000087-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.sensor.smoke|
|**Required Characteristics**|”9.95 Smoke Detected” (page 211)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.96 Status Active” (page 212)<br>”9.97 Status Fault” (page 212)<br>”9.100 Status Tampered” (page 214)<br>”9.99 Status Low Battery” (page 213)|

##### 8.36 Speaker





A Speaker service is to use to control the audio output settings on a speaker device.


This service requires iOS 10 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


152


8. Apple-defined Services








|Property|Value|
|---|---|
|**UUID**|00000113-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.speaker|
|**Required Characteristics**|”9.61 Mute” (page 188)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.127 Volume” (page 234)|


##### 8.37 Stateless Programmable Switch

This service describes a stateless programmable switch.


The following rules apply to a stateless programmable switch accessory:


  - Each physical switch on the accessory must be represented by a unique instance of this service.


  - If there are multiple instances of this service on the accessory, they must be linked to a ”8.32 Service Label”

(page 151).


  - If there are multiple instances of this service on the accessory, ”9.88 Service Label Index” (page 201) is a
required characteristic.


  - ”9.88 Service Label Index” (page 201) value for each instance of this service linked to the same ”8.32 Service
Label” (page 151) must be unique.


  - The User visible label on the physical accessory should match the ”9.89 Service Label Namespace” (page 202)
described by the accessory.


  - If there is only one instance of this service on the accessory, ”8.32 Service Label” (page 151) is not required
and consequently ”9.88 Service Label Index” (page 201) must not be present.


This service requires iOS 10.3 or later.



|Property|Value|
|---|---|
|**UUID**|00000089-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.stateless-programmable-switch|
|**Required Characteristics**|”9.75 Programmable Switch Event” (page 194)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.88 Service Label Index” (page 201)|

##### 8.38 Switch





This service describes a binary switch.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


153


8. Apple-defined Services

|Property|Value|
|---|---|
|**UUID**|00000049-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.switch|
|**Required Characteristics**|”9.70 On” (page 191)|
|**Optional Characteristics**|”9.62 Name” (page 188)|


##### 8.39 Target Control


This service handles the control of a selected target from the remote accessory. If an accessory can support control
of multiple concurrent Apple TVs at the same time without requiring the user to select an Apple TV on the remote
accessory UI, it must expose multiple instances of this service.


This service requires iOS 12 or later.







|Property|Value|
|---|---|
|**UUID**|00000125-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.target-control|
|**Required Characteristics**|”9.4 Active Identifier” (page 159)<br>”9.3 Active” (page 159)<br>”9.12 Button Event” (page 163)|
|**Optional Characteristics**|”9.62 Name” (page 188)|

##### 8.40 Target Control Management

This service manages the configuration for a remote accessory and allows it to indicate the supported configuration.
This service must be marked as primary service for an accessory whose primary functionality is to act as a target
controller (e.g., Apple TV remote accessory).


This service requires iOS 12 or later.





|Property|Value|
|---|---|
|**UUID**|00000122-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.target-control-management|
|**Required Characteristics**|”9.113 Target Control Supported Configuration” (page 224)<br>”9.114 Target Control List” (page 225)|


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


154


8. Apple-defined Services


##### 8.41 Temperature Sensor

This service describes a Temperature Sensor.


This service requires iOS 9 or later.






|Property|Value|
|---|---|
|**UUID**|0000008A-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.sensor.temperature|
|**Required Characteristics**|”9.35 Current Temperature” (page 175)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.96 Status Active” (page 212)<br>”9.97 Status Fault” (page 212)<br>”9.99 Status Low Battery” (page 213)<br>”9.100 Status Tampered” (page 214)|


##### 8.42 Thermostat

This service describes a thermostat.



|Property|Value|
|---|---|
|**UUID**|0000004A-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.thermostat|
|**Required Characteristics**|”9.32 Current Heating Cooling State” (page 173)<br>”9.119 Target Heating Cooling State” (page 230)<br>”9.35 Current Temperature” (page 175)<br>”9.121 Target Temperature” (page 231)<br>”9.122 Temperature Display Units” (page 231)|
|**Optional Characteristics**|”9.20 Cooling Threshold Temperature” (page 167)<br>”9.34 Current Relative Humidity” (page 174)<br>”9.42 Heating Threshold Temperature” (page 178)<br>”9.62 Name” (page 188)<br>”9.120 Target Relative Humidity” (page 231)|

##### 8.43 Valve





This service describes accessories like irrigation valves or water outlets. A valve is set to _`In Use`_ when there are fluid
flowing through the valve.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


155


8. Apple-defined Services


If an accessory has this service with ”9.124 Valve Type” (page 232) set to Irrigation it must include the ”9.112 Set
Duration” (page 223) and ”9.78 Remaining Duration” (page 195) characteristic on the ”8.43 Valve” (page 155) service.


”9.88 Service Label Index” (page 201) must be present on each instance of this service if the accessory consists of:


  - a bridge accessory (the ”8.32 Service Label” (page 151) service must be included here) which includes multiple
bridged accessories each with ”8.43 Valve” (page 155) service.


  - an accessory (the ”8.32 Service Label” (page 151) service must be included here) which includes multiple
linked ”8.43 Valve” (page 155) services


If an accessory has this service with ”9.88 Service Label Index” (page 201) included, the default ”9.62 Name” (page 188)
must be empty string unless user has already assigned a name to this valve before accessory is HomeKit paired. In
such a case, the default name should be the user configured name for this valve.


”9.49 Is Configured” (page 182) must be present on each instance of this service if the accessory is used in an irrigation system or shower system where all valves may not be configured to use (e.g., depending on physical wire
connection).


This characteristic requires iOS 11.2 or later.


Setting the value of ”9.3 Active” (page 159) to _`Active`_ on this service must result in ”8.21 Irrigation System” (page 145)
bridge to be set to _`Active`_ if this service is used in context of an Irrigation system.


This service requires iOS 11.2 or later.



|Property|Value|
|---|---|
|**UUID**|000000D0-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.valve|
|**Required Characteristics**|”9.3 Active” (page 159)<br>”9.48 In Use” (page 181)<br>”9.124 Valve Type” (page 232)|
|**Optional Characteristics**|”9.112 Set Duration” (page 223)<br>”9.78 Remaining Duration” (page 195)<br>”9.49 Is Configured” (page 182)<br>”9.88 Service Label Index” (page 201)<br>”9.97 Status Fault” (page 212)<br>”9.62 Name” (page 188)|

##### 8.44 Window





This service describes a motorized window.


This service requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


156


8. Apple-defined Services








|Property|Value|
|---|---|
|**UUID**|0000008B-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.window|
|**Required Characteristics**|”9.27 Current Position” (page 170)<br>”9.117 Target Position” (page 229)<br>”9.73 Position State” (page 192)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.43 Hold Position” (page 179)<br>”9.65 Obstruction Detected” (page 189)|


##### 8.45 Window Covering

This service describes motorized window coverings or shades - examples include shutters, blinds, awnings etc.


This service requires iOS 9 or later.





|Property|Value|
|---|---|
|**UUID**|0000008C-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.window-covering|
|**Required Characteristics**|”9.117 Target Position” (page 229)<br>”9.27 Current Position” (page 170)<br>”9.73 Position State” (page 192)|
|**Optional Characteristics**|”9.62 Name” (page 188)<br>”9.43 Hold Position” (page 179)<br>”9.24 Current Horizontal Tilt Angle” (page 169)<br>”9.115 Target Horizontal Tilt Angle” (page 227)<br>”9.28 Current Vertical Tilt Angle” (page 171)<br>”9.123 Target Vertical Tilt Angle” (page 232)<br>”9.65 Obstruction Detected” (page 189)|


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


157


### 9 Apple-defined Characteristics

##### 9.1 Overview

This section specifies predefined characteristics and their properties. Each characteristic has a unique UUID.


Accessories must use Apple-defined characteristics to expose functionality of the accessory if they are available; e.g.,
a temperature sensor must use the Apple-defined ”9.35 Current Temperature” (page 175) characteristic rather than
defining its own custom characteristic to expose the same functionality.


Note that all the characteristics with the format bool must expose/accept a Boolean value expressed as one of the
following: true, false, 0 (false), or 1 (true).


Additionally, if a set of valid values is specified, for example as in ”9.122 Temperature Display Units” (page 231), the
characteristic must only expose/accept these values.


9.1.1 Overriding Properties


Each of the characteristics in this chapter is defined by Apple. Some include default properties about the characteristic, such as a minimum value or maximum value. The following properties of an Apple-defined characteristic may be
modified in order to better fit the specific application:


  - Minimum Value


  - Maximum Value


  - Step Value


  - Maximum Length


  - Maximum Data Length


An example of modifying the default properties of an Apple-defined characteristic is using the Current Temperature
characteristic, which has a default minimum value of 0°C, for an outdoor temperature sensor. Rather than creating a
new characteristic, the accessory can simply set the “minimum value” property to -30°C.


The accessory must specify the new values used as part of the metadata information when modifying the default
properties. Percentages are excluded from properties that can be overridden.

##### 9.2 Accessory Flags


When set indicates accessory requires additional setup.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


158


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|000000A6-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.accessory-properties|
|**Permissions**|Paired Read, Notify|
|**Format**|uint32|
|**Valid Values**|0x0001 (bit0)<br>”Requires additional setup”<br>0x0002 - 0xFFFF<br>”Reserved”|


##### 9.3 Active

The Active characteristic indicates whether the service is currently active.


This characteristic requires iOS 10.3 or later.






|Property|Value|
|---|---|
|**UUID**|000000B0-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.active|
|**Permissions**|Paired Write, Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Inactive”<br>1<br>”Active”<br>2-255<br>”Reserved”|


##### 9.4 Active Identifier

This HAP characteristic allows the accessory to indicate the target that is currently selected in the UI of the accessory
(e.g. remote accessory which can control multiple Apple TVs).


This characteristic requires iOS 12 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


159


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|000000E7-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.active-identifier|
|**Permissions**|Paired Read, Notify|
|**Format**|uint32|



The value of this characteristic is one of the Target Identifier values configured by a controller in the Target Control
List HAP characteristic of the Target Control Management HAP service. If no target is currently selected, the value
must be 0 (for e.g., a remote accessory is currently controlling a non-HomeKit entity).


When the value of this characteristic is changed - either due to user selecting a different target or due to a management
operation (such as removing the currently active target), the Active characteristic (000000B0) must be reset back to
Inactive.

##### 9.5 Administrator Only Access


When this mode is enabled, the accessory only accepts administrator access.

|Property|Value|
|---|---|
|**UUID**|00000001-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.administrator-only-access|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|bool|


##### 9.6 Audio Feedback


This characteristic describes whether audio feedback (e.g. a beep, or other external sound mechanism) is enabled.

|Property|Value|
|---|---|
|**UUID**|00000005-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.audio-feedback|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|bool|


##### 9.7 Air Particulate Density


This characteristic indicates the current air particulate matter density in micrograms/m [3] .


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


160


9. Apple-defined Characteristics



This characteristic requires iOS 9 or later.

|Property|Value|
|---|---|
|**UUID**|00000064-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.air-particulate.density|
|**Permissions**|Paired Read, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|1000|


##### 9.8 Air Particulate Size


This characteristic indicates the size of air particulate matter in micrometers.


This characteristic requires iOS 9 or later.






|Property|Value|
|---|---|
|**UUID**|00000065-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.air-particulate.size|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”2.5 Micrometers”<br>1<br>”10 Micrometers”<br>2-255<br>”Reserved”|


##### 9.9 Air Quality

This characteristic describes the subject assessment of air quality by an accessory.


This characteristic requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


161


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|00000095-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.air-quality|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|5|
|**Step Value**|1|
|**Valid Values**|0<br>”Unknown”<br>1<br>”Excellent”<br>2<br>”Good”<br>3<br>”Fair”<br>4<br>”Inferior”<br>5<br>”Poor”|


##### 9.10 Battery Level

This characteristic describes the current level of the battery.


This characteristic requires iOS 9 or later.

|Property|Value|
|---|---|
|**UUID**|00000068-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.battery-level|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|100|
|**Step Value**|1|
|**Unit**|percentage|


##### 9.11 Brightness


This characteristic describes a perceived level of brightness, e.g. for lighting, and can be used for backlights or color.
The value is expressed as a percentage (%) of the maximum level of supported brightness.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


162


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|00000008-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.brightness|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|int|
|**Minimum Value**|0|
|**Maximum Value**|100|
|**Step Value**|1|
|**Unit**|percentage|


##### 9.12 Button Event


Notifications on this characteristic can only be enabled by Admin controllers. Any requests to enable notification on
this characteristic by non admin controllers must result in error -70401 (Insufficient Privileges).


This characteristic requires iOS 12 or later.

|Property|Value|
|---|---|
|**UUID**|00000126-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.button-event|
|**Permissions**|Paired Read, Notify|
|**Format**|tlv8|



The value of this characteristic is a TLV8-encoded list of supported parameters. The list of types for the TLVs area as
follows:


**Table 9-1:** Button Event TLV8 Definition

|Type|Name|Format|Description|
|---|---|---|---|
|1|Button ID|1|ID of button; a value of 0 is invalid.|
|2|Button State|1|State of the button;<br>0-Up<br>1-Down|
|3|Timestamp|8|Timestamp of the event.<br>Units are ticks|
|4|Active Identifier|4|Identifier of the target; value is a uint32.|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


163


9. Apple-defined Characteristics

##### 9.13 Carbon Monoxide Level


This characteristic indicates the Carbon Monoxide levels detected in parts per million (ppm).


This characteristic requires iOS 9 or later.

|Property|Value|
|---|---|
|**UUID**|00000090-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.carbon-monoxide.level|
|**Permissions**|Paired Read, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|100|


##### 9.14 Carbon Monoxide Peak Level


This characteristic indicates the highest detected level (ppm) of Carbon Monoxide detected by a sensor.


This characteristic requires iOS 9 or later.

|Property|Value|
|---|---|
|**UUID**|00000091-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.carbon-monoxide.peak-level|
|**Permissions**|Paired Read, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|100|


##### 9.15 Carbon Dioxide Detected


This characteristic indicates if a sensor detects abnormal levels of Carbon Dioxide. Value should revert to 0 after the
Carbon Dioxide levels drop to normal levels.


This characteristic requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


164


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|00000092-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.carbon-dioxide.detected|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Carbon Dioxide levels are normal”<br>1<br>”Carbon Dioxide levels are abnormal”|


##### 9.16 Carbon Dioxide Level

This characteristic indicates the detected level of Carbon Dioxide in parts per million (ppm).


This characteristic requires iOS 9 or later.

|Property|Value|
|---|---|
|**UUID**|00000093-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.carbon-dioxide.level|
|**Permissions**|Paired Read, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|100000|


##### 9.17 Carbon Dioxide Peak Level


This characteristic indicates the highest detected level (ppm) of carbon dioxide detected by a sensor.


This characteristic requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


165


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|00000094-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.carbon-dioxide.peak-level|
|**Permissions**|Paired Read, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|100000|


##### 9.18 Carbon Monoxide Detected


This characteristic indicates if a sensor detects abnormal levels of Carbon Monoxide. Value should revert to 0 after
the Carbon Monoxide levels drop to normal levels


This characteristic requires iOS 9 or later.






|Property|Value|
|---|---|
|**UUID**|00000069-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.carbon-monoxide.detected|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Carbon Monoxide levels are normal”<br>1<br>”Carbon Monoxide levels are abnormal”|


##### 9.19 Charging State

This characteristic describes the charging state of a battery or an accessory.


This characteristic requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


166


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|0000008F-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.charging-state|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|2|
|**Step Value**|1|
|**Valid Values**|0<br>”Not Charging”<br>1<br>”Charging”<br>2<br>”Not Chargeable”|


##### 9.20 Cooling Threshold Temperature

This characteristic describes the cooling threshold in Celsius for accessories that support simultaneous heating and
cooling. The value of this characteristic represents the maximum temperature that must be reached before cooling is
turned on.


For example, if the ”9.119 Target Heating Cooling State” (page 230) is set to Auto and the current temperature goes
above the maximum temperature, then the cooling mechanism should turn on to decrease the current temperature
until the minimum temperature is reached.

|Property|Value|
|---|---|
|**UUID**|0000000D-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.temperature.cooling-threshold|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|float|
|**Minimum Value**|10|
|**Maximum Value**|35|
|**Step Value**|0.1|
|**Unit**|celsius|


##### 9.21 Color Temperature


This characteristic describes color temperature which is represented in reciprocal megaKelvin (MK [-1] ) or mirek scale.
( _`M = 1,000,000 / K`_ where M is the desired mirek value and K is temperature in Kelvin)


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


167


9. Apple-defined Characteristics


If this characteristic is included in the ”8.23 Light Bulb” (page 147), ”9.44 Hue” (page 179) and ”9.82 Saturation”
(page 197) must not be included as optional characteristics in ”8.23 Light Bulb” (page 147). This characteristic must
not be used for lamps which support color.


This characteristic requires iOS 10.3 or later.

|Property|Value|
|---|---|
|**UUID**|000000CE-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.color-temperature|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|uint32|
|**Minimum Value**|50|
|**Maximum Value**|400|
|**Step Value**|1|


##### 9.22 Contact Sensor State


This characteristic describes the state of a door/window contact sensor. A value of 0 indicates that the contact is
detected. A value of 1 indicates that the contact is not detected.


This characteristic requires iOS 9 or later.






|Property|Value|
|---|---|
|**UUID**|0000006A-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.contact-state|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Contact is detected”<br>1<br>”Contact is not detected”|


##### 9.23 Current Ambient Light Level

This characteristic indicates the current light level. The value is expressed in Lux units (lumens/m [2] )


This characteristic requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


168


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|0000006B-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.light-level.current|
|**Permissions**|Paired Read, Notify|
|**Format**|float|
|**Minimum Value**|0.0001|
|**Maximum Value**|100000|
|**Unit**|lux|


##### 9.24 Current Horizontal Tilt Angle


This characteristic describes the current angle of horizontal slats for accessories such as windows, fans, portable
heater/coolers etc. This characteristic takes values between -90 and 90. A value of 0 indicates that the slats are
rotated to a fully open position. A value of -90 indicates that the slats are rotated all the way in a direction where the
user-facing edge is higher than the window-facing edge.


This characteristic requires iOS 9 or later.

|Property|Value|
|---|---|
|**UUID**|0000006C-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.horizontal-tilt.current|
|**Permissions**|Paired Read, Notify|
|**Format**|int|
|**Minimum Value**|-90|
|**Maximum Value**|90|
|**Step Value**|1|
|**Unit**|arcdegrees|


##### 9.25 Current Air Purifier State


This characteristic describes the current state of the air purifier.


This characteristic requires iOS 10.3 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


169


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|000000A9-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.air-purifier.state.current|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|2|
|**Step Value**|1|
|**Valid Values**|0<br>”Inactive”<br>1<br>”Idle”<br>2<br>”Purifying Air”|


##### 9.26 Current Slat State

This characteristic describes the current state of the slats.


This characteristic requires iOS 10.3 or later.






|Property|Value|
|---|---|
|**UUID**|000000AA-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.slat.state.current|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|2|
|**Step Value**|1|
|**Valid Values**|0<br>”Fixed”<br>1<br>”Jammed”<br>2<br>”Swinging”|


##### 9.27 Current Position

This characteristic describes the current position of accessories. This characteristic can be used with doors, windows,
awnings or window coverings. For windows and doors, a value of 0 indicates that a window (or door) is fully closed
while a value of 100 indicates a fully open position. For blinds/shades/awnings, a value of 0 indicates a position that
permits the least light and a value of 100 indicates a position that allows most light.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


170


9. Apple-defined Characteristics


This characteristic requires iOS 9 or later.

|Property|Value|
|---|---|
|**UUID**|0000006D-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.position.current|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|100|
|**Step Value**|1|
|**Unit**|percentage|


##### 9.28 Current Vertical Tilt Angle


This characteristic describes the current angle of vertical slats for accessories such as windows, fans, portable heater/coolers
etc. This characteristic takes values between -90 and 90. A value of 0 indicates that the slats are rotated to be fully
open. A value of -90 indicates that the slats are rotated all the way in a direction where the user-facing edge is to the
left of the window-facing edge.


This characteristic requires iOS 9 or later.

|Property|Value|
|---|---|
|**UUID**|0000006E-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.vertical-tilt.current|
|**Permissions**|Paired Read, Notify|
|**Format**|int|
|**Minimum Value**|-90|
|**Maximum Value**|90|
|**Step Value**|1|
|**Unit**|arcdegrees|


##### 9.29 Current Humidifier Dehumidifier State


This characteristic describes the current state of a humidifier or/and a dehumidifier.


This characteristic requires iOS 11 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


171


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|000000B3-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.humidifier-dehumidifier.state.current|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|3|
|**Step Value**|1|
|**Valid Values**|0<br>”Inactive”<br>1<br>”Idle”<br>2<br>”Humidifying”<br>3<br>”Dehumidifying”|


##### 9.30 Current Door State

This characteristic describes the current state of a door.





|Property|Value|
|---|---|
|**UUID**|0000000E-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.door-state.current|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|4|
|**Step Value**|1|
|**Valid Values**|0<br>”Open. The door is fully open.”<br>1<br>”Closed. The door is fully closed.”<br>2<br>”Opening. The door is actively opening.”<br>3<br>”Closing. The door is actively closing.”<br>4<br>”Stopped. The door is not moving, and it is not fully open nor fully<br>closed.”<br>5-255<br>”Reserved”|


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


172


9. Apple-defined Characteristics


##### 9.31 Current Fan State

This characteristic describes the current state of the fan.


This characteristic requires iOS 10.3 or later.






|Property|Value|
|---|---|
|**UUID**|000000AF-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.fan.state.current|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|2|
|**Step Value**|1|
|**Valid Values**|0<br>”Inactive”<br>1<br>”Idle”<br>2<br>”Blowing Air”|


##### 9.32 Current Heating Cooling State

This characteristic describes the current mode of an accessory that supports cooling or heating its environment, e.g.
a thermostat is ”heating” a room to 75 degrees Fahrenheit.





|Property|Value|
|---|---|
|**UUID**|0000000F-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.heating-cooling.current|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|2|
|**Step Value**|1|
|**Valid Values**|0<br>”Off.”<br>1<br>”Heat. The Heater is currently on.”<br>2<br>”Cool. Cooler is currently on.”<br>3-255<br>”Reserved”|


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


173


9. Apple-defined Characteristics


##### 9.33 Current Heater Cooler State

This characteristic describes the current state of a heater cooler.


This characteristic requires iOS 11 or later.






|Property|Value|
|---|---|
|**UUID**|000000B1-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.heater-cooler.state.current|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|3|
|**Step Value**|1|
|**Valid Values**|0<br>”Inactive”<br>1<br>”Idle”<br>2<br>”Heating”<br>3<br>”Cooling”|


##### 9.34 Current Relative Humidity

This characteristic describes the current relative humidity of the accessoryʼs environment. The value is expressed as
a percentage (%).

|Property|Value|
|---|---|
|**UUID**|00000010-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.relative-humidity.current|
|**Permissions**|Paired Read, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|100|
|**Step Value**|1|
|**Unit**|percentage|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


174


9. Apple-defined Characteristics

##### 9.35 Current Temperature


This characteristic describes the current temperature of the environment in Celsius irrespective of display units chosen
in ”9.122 Temperature Display Units” (page 231).

|Property|Value|
|---|---|
|**UUID**|00000011-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.temperature.current|
|**Permissions**|Paired Read, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|100|
|**Step Value**|0.1|
|**Unit**|celsius|


##### 9.36 Current Tilt Angle


This characteristic describes the current angle of slats for accessories such as windows, fans, portable heater/coolers
etc. This characteristic takes values between -90 and 90. A value of 0 indicates that the slats are rotated to be fully
open. At value 0 the user-facing edge and the window-facing edge are perpendicular to the window.


For _`Horizontal`_ slat (see ”9.94 Slat Type” (page 211)): A value of -90 indicates that the slats are rotated all the way
in a direction where the user-facing edge is to the left of the window-facing edge.


For _`Vertical`_ slat (see ”9.94 Slat Type” (page 211)): A value of -90 indicates that the slats are rotated all the way in
a direction where the user-facing edge is higher than the window-facing edge.


This characteristic requires iOS 10.3 or later.

|Property|Value|
|---|---|
|**UUID**|000000C1-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.tilt.current|
|**Permissions**|Paired Read, Notify|
|**Format**|int|
|**Minimum Value**|-90|
|**Maximum Value**|90|
|**Step Value**|1|
|**Unit**|arcdegrees|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


175


9. Apple-defined Characteristics

##### 9.37 Digital Zoom


A Digital Zoom characteristic allows the control of digital zoom of a video RTP service.


This characteristic requires iOS 10 or later.

|Property|Value|
|---|---|
|**UUID**|0000011D-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.zoom-digital|
|**Permissions**|Paired Write, Paired Read, Notify|
|**Format**|float|



The value of this characteristic represents the digital zoom multiplier to be applied on the image sourced by the video
RTP service that is sourcing the input image.

##### 9.38 Filter Life Level


This characteristic describes the current filter life level.


This characteristic requires iOS 10.3 or later.

|Property|Value|
|---|---|
|**UUID**|000000AB-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.filter.life-level|
|**Permissions**|Paired Read, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|100|
|**Step Value**|1|


##### 9.39 Filter Change Indication


This characteristic describes if a filter needs to be changed.


This characteristic requires iOS 10.3 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


176


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|000000AC-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.filter.change-indication|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Filter does not need to be changed”<br>1<br>”Filter needs to be changed”|


##### 9.40 Firmware Revision

This characteristic describes a firmware revision string x[.y[.z]] (e.g. ”100.1.1”):


  - <x> is the major version number, required.


   - <y> is the minor version number, required if it is non-zero or if <z> is present.


   - <z> is the revision version number, required if non-zero.


The firmware revision must follow the below rules:


   - <x> is incremented when there is significant change. e.g.,1.0.0, 2.0.0, 3.0.0, etc.


  - <y> is incremented when minor changes are introduced such as 1.1.0, 2.1.0, 3.1.0 etc.


  - <z> is incremented when bug-fixes are introduced such as 1.0.1, 2.0.1, 3.0.1 etc.


  - Subsequent firmware updates can have a lower <y> version only if <x> is incremented


  - Subsequent firmware updates can have a lower <z> version only if <x> or <y> is incremented


  - Each number (major, minor and revision version) must not be greater than (2^32 -1)


The characteristic value must change after every firmware update.

|Property|Value|
|---|---|
|**UUID**|00000052-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.firmware.revision|
|**Permissions**|Paired Read|
|**Format**|string|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


177


9. Apple-defined Characteristics

##### 9.41 Hardware Revision


This characteristic describes a hardware revision string x[.y[.z]] (e.g. ”100.1.1”) and tracked when the board or components of the same accessory is changed :


  - <x> is the major version number, required.


   - <y> is the minor version number, required if it is non-zero or if <z> is present.


   - <z> is the revision version number, required if non-zero.


The hardware revision must follow the below rules:


   - <x> is incremented when there is significant change. e.g.,1.0.0, 2.0.0, 3.0.0, etc.


  - <y> is incremented when minor changes are introduced such as 1.1.0, 2.1.0, 3.1.0 etc.


  - <z> is incremented when bug-fixes are introduced such as 1.0.1, 2.0.1, 3.0.1 etc.


  - Subsequent hardware updates can have a lower <y> version only if <x> is incremented


  - Subsequent hardware updates can have a lower <z> version only if <x> or <y> is incremented


The characteristic value must change after every hardware update.

|Property|Value|
|---|---|
|**UUID**|00000053-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.hardware.revision|
|**Permissions**|Paired Read|
|**Format**|string|


##### 9.42 Heating Threshold Temperature


This characteristic describes the heating threshold in Celsius for accessories that support simultaneous heating and
cooling. The value of this characteristic represents the minimum temperature that must be reached before heating is
turned on.


For example, if the ”9.119 Target Heating Cooling State” (page 230) is set to “Auto” and the current temperature goes
below the minimum temperature, then the heating mechanism should turn on to increase the current temperature until
the ʼminimum temperatureʼ is reached.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


178


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|00000012-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.temperature.heating-threshold|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|25|
|**Step Value**|0.1|
|**Unit**|celsius|


##### 9.43 Hold Position


This characteristic causes the service such as door or window covering to stop at its current position. A value of 1
must hold the state of the accessory. For e.g, the window must stop moving when this characteristic is written a value
of 1. A value of 0 should be ignored.


A write to ”9.117 Target Position” (page 229) characteristic will release the hold.


This characteristic requires iOS 9 or later.

|Property|Value|
|---|---|
|**UUID**|0000006F-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.position.hold|
|**Permissions**|Paired Write|
|**Format**|bool|


##### 9.44 Hue


This characteristic describes hue or color.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


179


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|00000013-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.hue|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|360|
|**Step Value**|1|
|**Unit**|arcdegrees|


##### 9.45 Identify


This characteristic enables accessory to run its _identify routine_ . To learn more, see ”6.7.6 Identify Routine” (page 76).


Only the ”8.1 Accessory Information” (page 134) is allowed to contain the Identify characteristic.

|Property|Value|
|---|---|
|**UUID**|00000014-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.identify|
|**Permissions**|Paired Write|
|**Format**|bool|


##### 9.46 Image Rotation


An Image Rotation characteristic allows the control of rotation of the image of a video RTP service.


This characteristic requires iOS 10 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


180


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|0000011E-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.image-rotation|
|**Permissions**|Paired Write, Paired Read, Notify|
|**Format**|float|
|**Valid Values**|0<br>”No rotation”<br>90<br>”Rotated 90 degrees to the right”<br>180<br>”Rotated 180 degrees to the right (flipped vertically)”<br>270<br>”Rotated 270 degrees to the right”|


##### 9.47 Image Mirroring

An Image Mirroring characteristic allows the control of mirroring state of the image of a video RTP service.


This characteristic requires iOS 10 or later.







|Property|Value|
|---|---|
|**UUID**|0000011F-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.image-mirror|
|**Permissions**|Paired Write, Paired Read, Notify|
|**Format**|bool|
|**Valid Values**|0<br>”Image is not mirrored”<br>1<br>”Image is mirrored”|
|**Unit**|arcdegrees|

##### 9.48 In Use

This characteristic describes if the service is in use. The service must be _`Active`_ before the value of this characteristic
can be set to in use.


This characteristic requires iOS 11.2 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


181


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|000000D2-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.in-use|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Not in use”<br>1<br>”In use”<br>2-255<br>”Reserved”|


##### 9.49 Is Configured

This characteristic describes if the service is configured for use. For example, all of the valves in an irrigation system
may not be configured depending on physical wire connection.


If the accessory supports updating through HAP, then it must also advertise Paired Write in the permissions.


This characteristic requires iOS 12.x.





|Property|Value|
|---|---|
|**UUID**|000000D6-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.is-configured|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Not Configured”<br>1<br>”Configured”<br>2-255<br>”Reserved”|


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


182


9. Apple-defined Characteristics

##### 9.50 Leak Detected


This characteristic indicates if a sensor detected a leak (e.g. water leak, gas leak). A value of 1 indicates that a leak is
detected. Value should return to 0 when leak stops.


This characteristic requires iOS 9 or later.






|Property|Value|
|---|---|
|**UUID**|00000070-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.leak-detected|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Leak is not detected”<br>1<br>”Leak is detected”|


##### 9.51 Lock Control Point

The accessory accepts writes to this characteristic to perform vendor-specific actions as well as those defined by
the ”8.25 Lock Management” (page 148) of the ”10.2 Lock” (page 236) . For example, user management related
functions should be defined and performed using this characteristic.

|Property|Value|
|---|---|
|**UUID**|00000019-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.lock-management.control-point|
|**Permissions**|Paired Write|
|**Format**|tlv8|


##### 9.52 Lock Current State


The current state of the physical security mechanism (e.g. deadbolt).


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


183


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|0000001D-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.lock-mechanism.current-state|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|3|
|**Step Value**|1|
|**Valid Values**|0<br>”Unsecured”<br>1<br>”Secured”<br>2<br>”Jammed”<br>3<br>”Unknown”<br>4-255<br>”Reserved”|


##### 9.53 Lock Last Known Action

The last known action of the lock mechanism (e.g. deadbolt).


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


184


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|0000001C-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.lock-mechanism.last-known-action|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|8|
|**Step Value**|1|
|**Valid Values**|0<br>”Secured using physical movement, interior”<br>1<br>”Unsecured using physical movement, interior”<br>2<br>”Secured using physical movement, exterior”<br>3<br>”Unsecured using physical movement, exterior”<br>4<br>”Secured with keypad”<br>5<br>”Unsecured with keypad”<br>6<br>”Secured remotely”<br>7<br>”Unsecured remotely”<br>8<br>”Secured with Automatic Secure timeout”<br>9-255<br>”Reserved”|


##### 9.54 Lock Management Auto Security Timeout

A value greater than 0 indicates if the lock mechanism enters the unsecured state, it will automatically attempt to
enter the secured state after n seconds, where n is the value provided in the write. A value of 0 indicates this feature
is disabled.

|Property|Value|
|---|---|
|**UUID**|0000001A-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.lock-management.auto-secure-timeout|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|uint32|
|**Unit**|seconds|


##### 9.55 Lock Physical Controls


This characteristic describes a way to lock a set of physical controls on an accessory (eg. child lock).


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


185


9. Apple-defined Characteristics



This characteristic requires iOS 10.3 or later.






|Property|Value|
|---|---|
|**UUID**|000000A7-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.lock-physical-controls|
|**Permissions**|Paired Write,Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Control lock disabled”<br>1<br>”Control lock enabled”|


##### 9.56 Lock Target State

The target state of the physical security mechanism (e.g. deadbolt).



|Property|Value|
|---|---|
|**UUID**|0000001E-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.lock-mechanism.target-state|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Unsecured”<br>1<br>”Secured”<br>2-255<br>”Reserved”|

##### 9.57 Logs





Read from this characteristic to get timestamped logs from the accessory. The data is in TLV8 format as defined by the
associated service profile. The ”8.25 Lock Management” (page 148), for example, defines its own specific structure
for the log data.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


186


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|0000001F-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.logs|
|**Permissions**|Paired Read, Notify|
|**Format**|tlv8|


##### 9.58 Manufacturer


This characteristic contains the name of the company whose brand will appear on the accessory, e.g., ”Acme”.

|Property|Value|
|---|---|
|**UUID**|00000020-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.manufacturer|
|**Permissions**|Paired Read|
|**Format**|string|
|**Maximum Length**|64|


##### 9.59 Model


This characteristic contains the manufacturer-specific model of the accessory, e.g. ”A1234”. The minimum length of
this characteristic must be 1.

|Property|Value|
|---|---|
|**UUID**|00000021-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.model|
|**Permissions**|Paired Read|
|**Format**|string|
|**Maximum Length**|64|


##### 9.60 Motion Detected


This characteristic indicates if motion (e.g. a person moving) was detected.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


187


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|00000022-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.motion-detected|
|**Permissions**|Paired Read, Notify|
|**Format**|bool|


##### 9.61 Mute


A Mute characteristic allows the control of audio input or output accessory respectively.


This characteristic requires iOS 10 or later.






|Property|Value|
|---|---|
|**UUID**|0000011A-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.mute|
|**Permissions**|Paired Write, Paired Read, Notify|
|**Format**|bool|
|**Valid Values**|0<br>”Mute is Off / Audio is On”<br>1<br>”Mute is On / There is no Audio”|



If the audio RTP service can support muting, this characteristic must support Paired Write permission as well.

##### 9.62 Name


This characteristic describes a name and must not be a null value.

|Property|Value|
|---|---|
|**UUID**|00000023-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.name|
|**Permissions**|Paired Read|
|**Format**|string|
|**Maximum Length**|64|


##### 9.63 Night Vision


A Night Vision characteristic allows the control of night vision mode on a video RTP service.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


188


9. Apple-defined Characteristics



This characteristic requires iOS 10 or later.






|Property|Value|
|---|---|
|**UUID**|0000011B-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.night-vision|
|**Permissions**|Paired Write, Paired Read, Notify|
|**Format**|bool|
|**Valid Values**|0<br>”Disable night-vision mode”<br>1<br>”Enable night-vision mode”|


##### 9.64 Nitrogen Dioxide Density

This characteristic indicates the current NO2 density in micrograms/m [3] .


This characteristic requires iOS 10.3 or later.

|Property|Value|
|---|---|
|**UUID**|000000C4-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.density.no2|
|**Permissions**|Paired Read, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|1000|


##### 9.65 Obstruction Detected


This characteristic describes the current state of an obstruction sensor, such as one that is used in a garage door. If
the state is true then there is an obstruction detected.

|Property|Value|
|---|---|
|**UUID**|00000024-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.obstruction-detected|
|**Permissions**|Paired Read, Notify|
|**Format**|bool|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


189


9. Apple-defined Characteristics

##### 9.66 PM2.5 Density


This characteristic indicates the current PM2.5 micrometer particulate density in micrograms/m [3] .


This characteristic requires iOS 10.3 or later.

|Property|Value|
|---|---|
|**UUID**|000000C6-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.density.pm2_5|
|**Permissions**|Paired Read, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|1000|


##### 9.67 Occupancy Detected


This characteristic indicates if occupancy was detected (e.g. a person present). A value of 1 indicates occupancy is
detected. Value should return to 0 when occupancy is not detected.


This characteristic requires iOS 9 or later.






|Property|Value|
|---|---|
|**UUID**|00000071-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.occupancy-detected|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Occupancy is not detected”<br>1<br>”Occupancy is detected”|


##### 9.68 Optical Zoom

A Digital Zoom characteristic allows the control of digital zoom of a video RTP service.


This characteristic requires iOS 10 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


190


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|0000011C-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.zoom-optical|
|**Permissions**|Paired Write, Paired Read, Notify|
|**Format**|float|



The value of this characteristic represents the optical zoom setting of the camera service that is sourcing the input
image.

##### 9.69 Outlet In Use


This characteristic describes if the power outlet has an appliance e.g., a floor lamp, physically plugged in. This characteristic is set to _`True`_ even if the plugged-in appliance is off.

|Property|Value|
|---|---|
|**UUID**|00000026-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.outlet-in-use|
|**Permissions**|Paired Read, Notify|
|**Format**|bool|


##### 9.70 On


This characteristic represents the states for “on” and “off”.

|Property|Value|
|---|---|
|**UUID**|00000025-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.on|
|**Permissions**|Paired Read,Paired Write, Notify|
|**Format**|bool|


##### 9.71 Ozone Density


This characteristic indicates the current ozone density in micrograms/m [3] .


This characteristic requires iOS 10.3 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


191


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|000000C3-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.density.ozone|
|**Permissions**|Paired Read, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|1000|


##### 9.72 PM10 Density


This characteristic indicates the current PM10 micrometer particulate density in micrograms/m [3] .


This characteristic requires iOS 10.3 or later.

|Property|Value|
|---|---|
|**UUID**|000000C7-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.density.pm10|
|**Permissions**|Paired Read, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|1000|


##### 9.73 Position State


This characteristic describes the state of the position of accessories. This characteristic can be used with doors,
windows, awnings or window coverings for presentation purposes.


This characteristic requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


192


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|00000072-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.position.state|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|2|
|**Step Value**|1|
|**Valid Values**|0<br>”Going to the minimum value specified in metadata”<br>1<br>”Going to the maximum value specified in metadata”<br>2<br>”Stopped”<br>3-255<br>”Reserved”|


##### 9.74 Program Mode

This characteristic describes if there are programs scheduled on the accessory. If there are Programs scheduled
on the accessory and the accessory is used for manual operation, the value of this characteristic must be _`Program`_

_`Scheduled, currently overridden to manual mode`_ .


This characteristic requires iOS 11.2 or later.





|Property|Value|
|---|---|
|**UUID**|000000D1-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.program-mode|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|2|
|**Step Value**|1|
|**Valid Values**|0<br>”No Programs Scheduled”<br>1<br>”Program Scheduled”<br>2<br>”Program Scheduled, currently overriden to manual mode”<br>3-255<br>”Reserved”|


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


193


9. Apple-defined Characteristics

##### 9.75 Programmable Switch Event


This characteristic describes an event generated by a programmable switch. Reading this characteristic must return
the last event triggered for BLE. For IP accessories, the accessory must set the value of Paired Read to null(i.e. ”value”
: null) in the attribute database. A read of this characteristic must always return a null value for IP accessories. The
value must only be reported in the events (”ev”) property.


This characteristic requires iOS 10.3 or later.






|Property|Value|
|---|---|
|**UUID**|00000073-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.input-event|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|2|
|**Step Value**|1|
|**Valid Values**|0<br>”Single Press”<br>1<br>”Double Press”<br>2<br>”Long Press”<br>3-255<br>”Reserved”|


##### 9.76 Relative Humidity Dehumidifier Threshold

This characteristic describes the relative humidity dehumidifier threshold. The value of this characteristic represents
the ʼmaximum relative humidityʼ that must be reached before dehumidifier is turned on.


This characteristic requires iOS 11 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


194


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|000000C9-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.relative-humidity.dehumidifier-threshold|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|100|
|**Step Value**|1|
|**Unit**|percentage|


##### 9.77 Relative Humidity Humidifier Threshold


This characteristic describes the relative humidity humidifier threshold. The value of this characteristic represents the
ʼminimum relative humidityʼ that must be reached before humidifier is turned on.


This characteristic requires iOS 11 or later.

|Property|Value|
|---|---|
|**UUID**|000000CA-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.relative-humidity.humidifier-threshold|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|100|
|**Step Value**|1|
|**Unit**|percentage|


##### 9.78 Remaining Duration


This characteristic describes the remaining duration on the accessory. Notifications on this characteristic must only
be used if the remaining duration increases/decreases from the accessoryʼs usual countdown of remaining duration
and when the duration reaches 0. e.g. It must not send notifications when the remaining duration is ticking down from
100,99,98... if 100 was the initial Set duration. However, if the remaining duration changes to 95 from 92 (increase)
or 85 from 92 (decrease which is not part of the usual duration countdown), it must send a notification.


This duration is defined in seconds.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


195


9. Apple-defined Characteristics


This characteristic requires iOS 11.2 or later.

|Property|Value|
|---|---|
|**UUID**|000000D4-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.remaining-duration|
|**Permissions**|Paired Read, Notify|
|**Format**|uint32|
|**Minimum Value**|0|
|**Maximum Value**|3600|
|**Step Value**|1|


##### 9.79 Reset Filter Indication


This characteristic allows a user to reset the filter indication. When the value of 1 is written to this characteristic by
the user, the accessory should reset it to 0 once the relevant action to reset the filter indication is executed. If the
accessory supports Filter Change Indication, the value of that characteristic should also reset back to 0.


This characteristic requires iOS 10.3 or later.

|Property|Value|
|---|---|
|**UUID**|000000AD-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.filter.reset-indication|
|**Permissions**|Paired Write|
|**Format**|uint8|
|**Minimum Value**|1|
|**Maximum Value**|1|


##### 9.80 Rotation Direction


This characteristic describes the direction of rotation of a fan.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


196


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|00000028-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.rotation.direction|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|int|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Clockwise”<br>1<br>”Counter-clockwise”<br>2-255<br>”Reserved”|


##### 9.81 Rotation Speed

This characteristic describes the rotation speed of a fan.

|Property|Value|
|---|---|
|**UUID**|00000029-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.rotation.speed|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|100|
|**Step Value**|1|
|**Unit**|percentage|


##### 9.82 Saturation


This characteristic describes color saturation.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


197


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|0000002F-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.saturation|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|100|
|**Step Value**|1|
|**Unit**|percentage|


##### 9.83 Security System Alarm Type


This characteristic describes the type of alarm triggered by a security system. A value of 1 indicates an ʼunknownʼ
cause. Value should revert to 0 when the alarm conditions are cleared.


This characteristic requires iOS 9 or later.

|Property|Value|
|---|---|
|**UUID**|0000008E-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.security-system.alarm-type|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|


##### 9.84 Security System Current State


This characteristic describes the state of a security system


This characteristic requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


198


9. Apple-defined Characteristics






|Property|Value|
|---|---|
|**UUID**|00000066-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.security-system-state.current|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|4|
|**Step Value**|1|
|**Valid Values**|0<br>”Stay Arm. The home is occupied and the residents are active. e.g.<br>morning or evenings”<br>1<br>”Away Arm. The home is unoccupied”<br>2<br>”Night Arm. The home is occupied and the residents are sleeping”<br>3<br>”Disarmed”<br>4<br>”Alarm Triggered”<br>5-255<br>”Reserved”|


##### 9.85 Security System Target State

This characteristic describes the target state of the security system.


This characteristic requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


199


9. Apple-defined Characteristics






|Property|Value|
|---|---|
|**UUID**|00000067-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.security-system-state.target|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|3|
|**Step Value**|1|
|**Valid Values**|0<br>”Stay Arm. The home is occupied and the residents are active. e.g.<br>morning or evenings”<br>1<br>”Away Arm. The home is unoccupied”<br>2<br>”Night Arm. The home is occupied and the residents are sleeping”<br>3<br>”Disarm”<br>4-255<br>”Reserved”|


##### 9.86 Selected Audio Stream Configuration

This is a control point characteristic that allows a controller to specify the selected audio attributes to be used for
streaming audio from the accessory.


This characteristic requires iOS 12 or later.

|Property|Value|
|---|---|
|**UUID**|00000128-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.selected-audio-stream-configuration|
|**Permissions**|Paired Read, Paired Write|
|**Format**|tlv8|



The value of this characteristic is a TLV8-encoded list of supported parameters.


**Table 9-2:** Selected Audio Input Stream Configuration TLV8 Definition

|Type|Name|Format|Description|
|---|---|---|---|
|1|Selected Audio Input Stream Configuration|N|The codec that is to be used for input-audio (ie, audio<br>sent from accessory to controller). This has the format<br>described below as the Selected Audio Stream Configu-<br>ration TLV.|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


200


9. Apple-defined Characteristics


The ”9.86 Selected Audio Stream Configuration” (page 200) TLV has the following form (which shares the same
format as _`Selected Audio Parameters`_ in the _`Selected RTP Stream Configuration`_ characteristic:


**Table 9-3:** Selected Audio Stream Configuration TLV TLV8 Definition

|Type|Name|Format|Description|
|---|---|---|---|
|1|Selected Audio Codec Type|1|(same as Selected Audio Parameter TLV 1, where Opus = 3)|
|2|Selected Audio Codec Parameters|N|Same as Selected Audio Parameter TLV 2, which is defined to be<br>the same as the Codec Param in the Supported Audio Stream Con-<br>figuration|


##### 9.87 Serial Number


This characteristic contains the manufacturer-specific serial number of the accessory, e.g. ”1A2B3C4D5E6F”. The
length must be greater than 1.

|Property|Value|
|---|---|
|**UUID**|00000030-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.serial-number|
|**Permissions**|Paired Read|
|**Format**|string|
|**Maximum Length**|64|


##### 9.88 Service Label Index


This characteristic should be used identify the index of the label that maps to ”9.89 Service Label Namespace” (page 202)
used by the accessory.


This characteristic requires iOS 10.3 or later.

|Property|Value|
|---|---|
|**UUID**|000000CB-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.service-label-index|
|**Permissions**|Paired Read|
|**Format**|uint8|
|**Minimum Value**|1|
|**Step Value**|1|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


201


9. Apple-defined Characteristics

##### 9.89 Service Label Namespace


This characteristic describes the naming schema for an accessory. For example, this characteristic can be used to describe the
type of labels used to identify individual services of an accessory.


This characteristic requires iOS 10.3 or later.






|Property|Value|
|---|---|
|**UUID**|000000CD-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.service-label-namespace|
|**Permissions**|Paired Read|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Dots. For e.g ”.” ”..” ”...” ”....””<br>1<br>”Arabic numerals. For e.g. 0,1,2,3”<br>2-255<br>”Reserved”|


##### 9.90 Setup Data Stream Transport

This is a control point characteristic which allows the controller to set up the data stream.


This characteristic requires iOS 12 or later.

|Property|Value|
|---|---|
|**UUID**|00000131-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.setup-data-stream-transport|
|**Permissions**|Paired Read, Paired Write, Write Response|
|**Format**|tlv8|



The value of this characteristic is a TLV8-encoded list of supported parameters.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


202


9. Apple-defined Characteristics


**Table 9-4:** Setup Data Steam Session TLV8 Definition

|Type|Name|Format|Description|
|---|---|---|---|
|1|Session Command Type|1|Session Command Type:<br>0 - Start Session<br>1 - 255 Reserved for use by Apple|
|2|Transport Type|1|See Transport Type in ”Supported” characteristic.|
|3|Controller Key Salt|32|See ”6.10.1 Data Stream Transport Security” (page 80)|



After a write is issued to this characteristic by the controller, the accessory must respond with a tlv8 encoded value with the
following parameters:


**Table 9-5:** Setup Data Stream Write Response TLV8 Definition

|Type|Name|Format|Description|
|---|---|---|---|
|1|Status|1|Status of the previous write issued:<br>0 - Success<br>1 - Generic error<br>2 - Busy, maximum number of transfer transport sessions<br>reached.<br>3 - 255 reserved for use by Apple|
|2|Transport Type Session Parameters|N|The transport type specific session parameters.|
|3|Accessory Key Salt|32|See ”6.10.1 Data Stream Transport Security” (page 80)|



The Transport Type Session Parameters TLV is encoded as a TLV8; the list of types for the value for HomeKit Data Stream over
TCP transport are as follows:


**Table 9-6:** Setup Data Stream Transport Configuration 3 TLV8 Definition

|Type|Name|Format|Description|
|---|---|---|---|
|1|TCP Listening Port|2|The port the accessory is listening to accept the transport connection.|



After the accessory receives the _`Start Session`_ command, it must receive the first packet from the controller on that port
within 10 seconds from the reception of this command.


After receiving the write-response, the controller must open a TCP connection to the provided port and send an initial _`hello`_
request. The controller will wait up to 10 seconds to receive the response and must not send any other message until it receives
it. If no message is received, or the controller receives any other message but a successful response, then it must close the
socket.


After receiving the connection, the accessory must validate that the first message received is a valid _`hello`_ request and it must
immediately reply. If no message is received before its 10 second timeout, or the accessory receives any other message, then it
must close the socket.


If the accessory has multiple pending connections, and there is ambiguity in which controller is connecting, e.g. it provides the
same port in all setup requests, it must attempt decrypting the first packet with each key that is a possible match. If none match,


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


203


9. Apple-defined Characteristics


then it must close the socket since it received a connection that did not have a valid _`hello`_ request as its first message. If a key is
tested but is not a match, the nonce for that key must not be changed, so that when the actual controller with that key connects,
that key is still usable.

##### 9.91 Selected RTP Stream Configuration


The Selected RTP Stream Configuration characteristic is a control point characteristic that allows a controller to specify the
selected video and audio attributes to be used for streaming audio and video from an IP camera accessory.


This characteristic requires iOS 10 or later.

|Property|Value|
|---|---|
|**UUID**|00000117-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.selected-rtp-stream-configuration|
|**Permissions**|Paired Read, Paired Write|
|**Format**|tlv8|



The write value of this characteristic is a TLV8-encoded list of selected audio/video/RTP parameters and their values. The list of
types for the TLVs are as follows:


**Table 9-7:** Selected RTP Stream Configuration






|Name|Type|Length|Description|
|---|---|---|---|
|Session Control|1|16|Session Control Command and Identifier|
|Selected Video Parameters|2|N|Video parameters selected for the streaming session|
|Selected Audio Parameters|3|N|Input Audio parameters selected for<br>the streaming session|



The Session Control Command TLV has a tlv8 encoded value that provides the response and the session identifier. The list of
types for the TLVs is as follows:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


204


9. Apple-defined Characteristics



**Table 9-8:** Session Control Command






|Name|Type|Length|Description|
|---|---|---|---|
|Session Identifier|1|16|UUID identifying the session that<br>identifies the command|
|Command|2|1|Session control command:<br>0 - End streaming session<br>1 - Start streaming session<br>2 - Suspend streaming session<br>3 - Resume streaming session<br>4 - Reconfigure streaming sessions<br>5 - 255 Reserved for use by Apple|



The Selected Video parameters TLV has a tlv8 encoded value that provides the selected video attributes such as codec information, image resolution, frame rate, RTP parameters etc., The list of types for the TLVs is as follows:


**Table 9-9:** Selected Video Parameters






|Name|Type|Length|Description|
|---|---|---|---|
|Selected Video Codec type|1|1|Type of video codec|
|Selected Video Codec parameters|2|N|Video Codec-specific parameters for<br>the streaming session|
|Selected Video attributes|3|N|Video attributes selected for the<br>streaming session|
|Selected Video RTP parameters|4|N|RTP parameters selected for the video<br>streaming session|



The encoding of Selected Video Codec Parameters and Selected Video Attributes TLVs is as described in ”9.105 Supported Video
Stream Configuration” (page 219)


The value of Video RTP parameters TLV is a TLV8-encoded list with the following types:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


205


9. Apple-defined Characteristics



**Table 9-10:** Video RTP Parameters












|Name|Type|Length|Description|
|---|---|---|---|
|Payload type|1|1|Type of video codec|
|SynchronizationSource for Video|2|4|SSRC for video stream|
|Maximum Bitrate|3|2|Maximum bit rate generated by the codec in<br>kbps and averaged over 1 second|
|Min RTCP interval|4|4|Minimum RTCP interval in seconds formatted as a 4 byte<br>little endian ieee754 floating point value|
|Max MTU|5|2|MTU<br>that the IP camera must use to transmit Video<br>RTP packets. This value will be<br>populated only if<br>the controller intends the camera to use a non-default<br>value<br>of the MTU|



The Selected Audio parameters TLV has a tlv8 encoded value that provides the selected audio attributes such as codec information, number of audio channels, RTP parameters etc., The list of types for the TLVs is as follows:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


206


9. Apple-defined Characteristics



**Table 9-11:** Selected Audio Parameters












|Name|Type|Length|Description|
|---|---|---|---|
|Selected Audio Codec type|1|1|Type of codec:<br>2 - AAC-ELD<br>3 - Opus<br>5 - AMR<br>6 - AMR-WB<br>7 - 255 Reserved for use by Apple|
|Selected Audio Codec parameters|2|N|Audio codec specific parameters|
|Selected Audio RTP parameters|3|N|RTP parameters selected for the streaming session|
|Comfort Noise|4|1|Boolean.<br>A value of 1 indicates that Comfort Noise<br>has been selected and that both<br>Camera and iOS<br>device will both use Comfort Noise codec|



The Selected Audio Codec Parameters TLV value has the same TLV types as described in ”9.102 Supported Audio Stream
Configuration” (page 215)


The value of Audio RTP parameters TLV is a TLV8-encoded list with the following types:


**Table 9-12:** Audio RTP Parameters












|Name|Type|Length|Description|
|---|---|---|---|
|Payload type|1|1|Payload type as defined in RFC 3551|
|SynchronizationSource for Audio|2|4|SSRC for audio stream|
|Maximum Bitrate|3|2|Maximum bit rate generated by the codec<br>in kbps and averaged over 1 second|
|Min RTCP interval|4|4|Minimum RTCP interval in seconds formatted as a 4 byte<br>little endian ieee754 floating point value|
|Comfort Noise Payload Type|6|1|Only<br>required when Comfort Noise is chosen<br>in the Selected Audio Parameters TLV|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


207


9. Apple-defined Characteristics

##### 9.92 Setup Endpoints


The Setup Endpoints characteristic allows a controller to exchange IP address and port information with the IP camera.


This characteristic requires iOS 10 or later.

|Property|Value|
|---|---|
|**UUID**|00000118-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.setup-endpoints|
|**Permissions**|Paired Read, Paired Write|
|**Format**|tlv8|



The write value of this characteristic is a TLV8-encoded list of the following parameters:


**Table 9-13:** Setup Endpoints

|Name|Type|Length|Description|
|---|---|---|---|
|Session ID|1|16|UUID identifying the session|
|Controller Address|3|N|Address of the controller for the streaming session|
|SRTP Parameters for Video|4|N|RTP parameters selected for the Video streaming session|
|SRTP Parameters for Audio|5|N|RTP parameters selected for the Audio streaming session|



The Controller Address TLV has a tlv8 encoded value that provides the IP address, and the port for the streaming session. The
list of types for the TLVs is as follows


**Table 9-14:** Controller Address












|Name|Type|Length|Description|
|---|---|---|---|
|IP address version|1|1|Version of IP Address:<br>0 - IPv4<br>1 - IPv6|
|IP Address|2|N|IP address of the controller|
|Video RTP port|3|2|Receive port of the controller for the<br>video stream of the RTP session|
|Audio RTP port|4|2|Receive port of the controller for the<br>audio stream of the RTP session|



Both the audio and video RTP port TLVs must be present even in case audio and video are multiplexed on the same port.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


208


9. Apple-defined Characteristics


The SRTP parameters TLV has a tlv8 encoded value that provides the SRTP crypto-suite and keys for the streaming session. The
accessory must populate a unique instance of this TLV for each supported SRTP Crypto Suite. When the SRTP Crypto Suite is
set to 2 (disabled), a zero-length SRTP Master Key as well as a zero-length SRTP Master Salt must be presented.


The list of types for the TLVs is as follows:


**Table 9-15:** SRTP Crypto Suite







|Name|Type|Length|Description|
|---|---|---|---|
|SRTP Crypto Suite|1|1|Supported SRTP Crypto Suite:<br>0 - AES_CM_128_HMAC_SHA1_80<br>1 - AES_256_CM_HMAC_SHA1_80<br>2 - Disabled<br>3 - 255 Reserved for use by Apple|
|SRTP Master Key|2|16 or 32|Master key for the SRTP session:<br>16 - AES_CM_128_HMAC_SHA1_80<br>32 - AES_256_CM_HMAC_SHA1_80|
|SRTP Master Salt|3|14|Master salt for the SRTP session|


If the accessory is able to parse the write command, it must respond with Success (i.e with a HTTP 204 No Content if all write(s)
in the request succeed, or a HTTP 207 Multi-Status response including HAP status code indicating success for this write - in the
context of a multi-write request).


After a write is issued to this characteristic by the controller, the next read of this characteristic indicates the status of the write
command. The read response is encoded as a TLV8 list with the following types:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


209


9. Apple-defined Characteristics



**Table 9-16:** Read Response







|Name|Type|Length|Description|
|---|---|---|---|
|Session Identifier|1|16|UUID<br>identifying the session that the command applies to|
|Status|2|1|0 - Success<br>1 - Busy<br>2 - Error<br>3 - 255 Reserved for<br>use by Apple|
|Accessory Address|3|N|Address of the IP camera for the<br>streaming session.|
|SRTP Parameters for Video|4|N|RTP parameters selected for the video<br>streaming session|
|SRTP Parameters for Audio|5|N|RTP parameters selected for the audio<br>streaming session|
|SynchronizationSource for Video|6|4|SSRC for video RTP stream|
|SynchronizationSource for Audio|7|4|SSRC for audio RTP stream|


The Accessory Address TLV has a tlv8 encoded value with the same types as described for Controller Address TLV above.


The IP Address Version in the Accessory Address TLV must be the same as the IP Address Version in the Controller Address TLV.


If the accessory receives a read request on this characteristic prior to any write request, the accessory must:


   - Respond with HAP Success, i.e with a HTTP 200 OK if all read(s) in the request succeed or a HTTP 207 Multi-Status
response including HAP status code indicating success for this read if some of the reads fail


   - Include Status = Error in the corresponding TLV (omitting the session identifier)


If the accessory is unable to set up a stream because all possible streams are being used, it must:


   - Respond to the following read request with HAP Success, i.e with a HTTP 200 OK if all read(s) in the request succeed, or
a HTTP 207 Multi-Status response including HAP status code indicating success for this read if some of the reads fail


   - Include Status = Busy in the corresponding TLV (including the session identifier)

##### 9.93 Siri Input Type


This characteristic describes the type of Siri input used by the accessory.


This characteristic requires iOS 12 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


210


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|00000132-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.siri-input-type|
|**Permissions**|Paired Read|
|**Format**|uint8|
|**Valid Values**|0<br>”Push button triggered Apple TV”<br>1-255<br>”Reserved”|


##### 9.94 Slat Type

This characteristic describes the type of the slats. If the slats can tilt on a horizontal axis, the value of this characteristic must be
set to _`Horizontal`_ . If the slats can tilt on a vertical axis, the value of this characteristic must be set to _`Vertical`_ .


This characteristic requires iOS 10.3 or later.






|Property|Value|
|---|---|
|**UUID**|000000C0-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.type.slat|
|**Permissions**|Paired Read|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Horizontal”<br>1<br>”Vertical”|


##### 9.95 Smoke Detected

This characteristic indicates if a sensor detects abnormal levels of smoke. A value of 1 indicates that smoke levels are abnormal.
Value should return to 0 when smoke levels are normal.


This characteristic requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


211


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|00000076-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.smoke-detected|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Smoke is not detected”<br>1<br>”Smoke is detected”|


##### 9.96 Status Active

This characteristic describes an accessoryʼs current working status. A value of true indicates that the accessory is active and is
functioning without any errors.


This characteristic requires iOS 9 or later.

|Property|Value|
|---|---|
|**UUID**|00000075-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.status-active|
|**Permissions**|Paired Read, Notify|
|**Format**|bool|


##### 9.97 Status Fault


This characteristic describes an accessory which has a fault. A non-zero value indicates that the accessory has experienced a
fault that may be interfering with its intended functionality. A value of 0 indicates that there is no fault.


This characteristic requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


212


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|00000077-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.status-fault|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”No Fault”<br>1<br>”General Fault”|


##### 9.98 Status Jammed

This characteristic describes an accessory which is in a jammed state. A status of 1 indicates that an accessoryʼs mechanisms
are jammed prevents it from functionality normally. Value should return to 0 when conditions that jam the accessory are rectified.


This characteristic requires iOS 9 or later.






|Property|Value|
|---|---|
|**UUID**|00000078-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.status-jammed|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Not Jammed”<br>1<br>”Jammed”|


##### 9.99 Status Low Battery

This characteristic describes an accessoryʼs battery status. A status of 1 indicates that the battery level of the accessory is low.
Value should return to 0 when the battery charges to a level thats above the low threshold.


This characteristic requires iOS 9 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


213


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|00000079-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.status-lo-batt|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Battery level is normal”<br>1<br>”Battery level is low”|


##### 9.100 Status Tampered

This characteristic describes an accessory which has been tampered with. A status of 1 indicates that the accessory has been
tampered with. Value should return to 0 when the accessory has been reset to a non-tampered state.


This characteristic requires iOS 9 or later.






|Property|Value|
|---|---|
|**UUID**|0000007A-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.status-tampered|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Accessory is not tampered”<br>1<br>”Accessory is tampered with”|


##### 9.101 Streaming Status

A Streaming Status characteristic allows an IP Camera accessory to describe the status of the RTP Stream Management service.


This characteristic requires iOS 10 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


214


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|00000120-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.streaming-status|
|**Permissions**|Paired Read, Notify|
|**Format**|tlv8|



The value of this characteristic is a TLV8-encoded list of supported parameters. The list of types for the TLVs are as follows:


**Table 9-17:** Streaming Status






|Name|Type|Length|Description|
|---|---|---|---|
|Status|1|1|Status of the stream RTP management service<br>0 - Available<br>1 - In Use<br>2 - Unavailable<br>3 - 255 Reserved for use by Apple|


##### 9.102 Supported Audio Stream Configuration

A Supported Audio Stream Configuration characteristic allows an accessory to indicate the parameters supported for streaming
audio (from a microphone and/or to a speaker) over an RTP session.


This characteristic requires iOS 10 or later.

|Property|Value|
|---|---|
|**UUID**|00000115-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.supported-audio-configuration|
|**Permissions**|Paired Read|
|**Format**|tlv8|



The value of this characteristic is a TLV8-encoded list of supported parameters. The list of types for the TLVs are as follows:


**Table 9-18:** Supported Audio Stream Configuration

|Name|Type|Length|Description|
|---|---|---|---|
|Audio Codec Configuration|1|N|Codec information and the configurations supported for the<br>codec|
|Comfort Noise support|2|1|Boolean, indicating support for Comfort Noise Codec|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


215


9. Apple-defined Characteristics


An IP Camera supporting multiple audio codecs must include one instance of the above TLV per supported audio codec. The
Audio Codec Configuration is encoded as a TLV8. The list of types for this TLV are as follows:


**Table 9-19:** Audio Codecs







|Name|Type|Length|Description|
|---|---|---|---|
|Codec type|1|2|Type of codec:<br>2 - AAC-ELD<br>3 - Opus<br>5 - AMR<br>6- AMR-WB<br>7- 255 Reserved for use by Apple|
|Audio Codec Parameters|2|N|Codec-specific parameters|


An IP camera must support the RTP Times listed in the table below


**Table 9-20:** Mandatory RTP Time Values

|RTP Time|Audio Codecs|
|---|---|
|20ms, 40ms, 60ms|AMR, AMR-WB, AAC-ELD 24K, Opus 16K, Opus 24K|
|30ms, 60ms|AAC-ELD 16K|



The Audio Codec parameters are encoded as a tlv8 - the list of types are as follows:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


216


9. Apple-defined Characteristics



**Table 9-21:** Audio Codec Parameters






|Name|Type|Length|Description|
|---|---|---|---|
|Audio channels|1|1|Number of audio channels. Default is 1|
|Bit-rate|2|1|0 - Variable bit-rate<br>1- Constant bit-rate|
|Sample rate|3|1|0 - 8KHz<br>1 - 16 KHz<br>2 - 24 KHz<br>3 - Reserved for use by Apple|
|RTP time|4|1|Packet Time - Length of time represented by the media in a packet RFC 4566.<br>Supported values - 20ms, 30ms, 40 ms & 60ms<br>_Note: This TLV will only be presented in the Selected Audio_<br>_Codec Parameters TLV_|


##### 9.103 Supported Data Stream Transport Configuration

This characteristics describes the data stream transport supported by the accessory.


This characteristic requires iOS 12 or later.

|Property|Value|
|---|---|
|**UUID**|00000130-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.supported-data-stream-transport-configuration|
|**Permissions**|Paired Read|
|**Format**|tlv8|



The value of this characteristic is a TLV8-encoded list of supported parameters.


**Table 9-22:** Transfer Transport Configuration TLV8 Definition

|Type|Name|Format|Description|
|---|---|---|---|
|1|Transfer Transport Configuration|N|The configuration supported for the transport.<br>There is one TLV of this type per supported transport type.|



An accessory supporting multiple transport types must include one instance of the above TLV per supported transport type. The
”9.103 Supported Data Stream Transport Configuration” (page 217) is encoded as a TLV8.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


217


9. Apple-defined Characteristics


The list of types for this TLV are as follows:


**Table 9-23:** Transport Type TLV8 Definition

|Type|Name|Format|Description|
|---|---|---|---|
|1|Transport Type|1|Type of transport:<br>0 - HomeKit Data Stream (See ”6.10 HomeKit Data Stream” (page 80)) over TCP<br>1 - 255 Reserved for use by Apple|


##### 9.104 Supported RTP Configuration


The Supported RTP Configuration characteristic allows an accessory to describe the supported configuration parameters for the
RTP video service used for streaming and other operations.


This characteristic requires iOS 10 or later.

|Property|Value|
|---|---|
|**UUID**|00000116-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.supported-rtp-configuration|
|**Permissions**|Paired Read|
|**Format**|tlv8|



The value of this characteristic is a TLV8-encoded list of supported RTP parameters and their values. The list of types for the
TLVs are as follows:


**Table 9-24:** Supported RTP Configuration






|Name|Type|Length|Description|
|---|---|---|---|
|SRTP Crypto Suite|2|1|Supported SRTP Crypto Suite:<br>0 - AES_CM_128_HMAC_SHA1_80<br>1 - AES_256_CM_HMAC_SHA1_80<br>2 - Disabled<br>3 - 255 Reserved for use by Apple<br>If multiple crypto suites are supported, multiple instances of this TLV<br>should be present. Use delimiter_` 0x00`_ to separate TLV items.|



The controller will configure the selected RTP parameters using the selected stream configuration characteristic.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


218


9. Apple-defined Characteristics

##### 9.105 Supported Video Stream Configuration


A Supported Video Stream Configuration characteristic allows an IP Camera accessory to describe the parameters supported
for streaming video over an RTP session. Status characteristic allows an IP Camera accessory to describe the status of the RTP
Stream Management service.


This characteristic requires iOS 10 or later.

|Property|Value|
|---|---|
|**UUID**|00000114-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.supported-video-stream-configuration|
|**Permissions**|Paired Read|
|**Format**|tlv8|



The value of this characteristic is a TLV8-encoded list of supported parameters. The list of types for the TLVs are as follows:


**Table 9-25:** Supported Video Stream Configuration






|Name|Type|Length|Description|
|---|---|---|---|
|Video Codec Configuration|1|N|Codec information and the configurations supported for the<br>codec.<br>There is one TLV of this type per supported codec|



An IP Camera supporting multiple video codecs must include one instance of the above TLV per supported video codec.


The Video Codec Configuration is encoded as a TLV8. The list of types for this TLVʼs value are as follows:


**Table 9-26:** Video Codec Configuration







|Name|Type|Length|Description|
|---|---|---|---|
|Video Codec Type|1|N|Type of video codec:<br>0 - H.264<br>1 - 255 Reserved for use by Apple|
|Video Codec Parameters|2|N|Video Codec-specific parameters|
|Video Attributes|3|N|Video Attributes supported for the codec.|


The Video Codec parameters TLV is encoded as a TLV8; the list of types for the value for a H.264 codec are as follows:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


219


9. Apple-defined Characteristics



**Table 9-27:** Video Codec Parameters







|Name|Type|Length|Description|
|---|---|---|---|
|ProfileID|1|1|Type of H.264 Profile:<br>0 - Constrained Baseline Profile<br>1 - Main Profile<br>Note:Interlaced coding (PicAFF, MBAFF) must not be used<br>2 - High Profile<br>Note:Interlaced coding (PicAFF, MBAFF) must not be used<br>3 - 255 Vendor-specific<br>One instance of this TLV must be present for each supported profile|
|Level|2|1|Profile<br>support level:<br>0 - 3.1<br>1 - 3.2<br>2 - 4<br>3 - 255 Reserved for use by Apple|
|Packetization mode|3|1|Packetization Mode<br>0 - Non-interleaved mode<br>1 - 255 Reserved for use by Apple<br>One instance of this TLV must be present for each supported mode|
|CVO Enabled|4|1|0 - CVO not supported<br>1 - CVO supported|
|CVO ID|5|1|ID for CVO RTP extension. This must be a value in the range [1-14]|


The Video attributes allow the accessory to indicate supported resolutions, frame rates etc., This information is encoded as a
TLV8; the list of types for the value of this TLV are as follows:


**Table 9-28:** Video Attributes

|Name|Type|Length|Description|
|---|---|---|---|
|Image width|1|2|Image width in pixels|
|Image height|2|2|Image height in pixels|
|Frame rate|3|1|Maximum frame rate|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


220


9. Apple-defined Characteristics


An IP camera accessory supporting encoding video at different resolutions must include multiple instances of Video attributes
TLV.

##### 9.106 Sulphur Dioxide Density


This characteristic indicates the current SO2 density in micrograms/m [3] .


This characteristic requires iOS 10.3 or later.

|Property|Value|
|---|---|
|**UUID**|000000C5-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.density.so2|
|**Permissions**|Paired Read, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|1000|


##### 9.107 Swing Mode


This characteristic describes if swing mode is enabled.


This characteristic requires iOS 10.3 or later.






|Property|Value|
|---|---|
|**UUID**|000000B6-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.swing-mode|
|**Permissions**|Paired Read, Notify, Paired Write|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Swing disabled”<br>1<br>”Swing enabled”|


##### 9.108 Target Air Purifier State

This characteristic describes the target state of the air purifier.


This characteristic requires iOS 10.3 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


221


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|000000A8-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.air-purifier.state.target|
|**Permissions**|Paired Write, Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Manual”<br>1<br>”Auto”|


##### 9.109 Target Fan State

This characteristic describes the target state of the fan.


This characteristic requires iOS 10.3 or later.






|Property|Value|
|---|---|
|**UUID**|000000BF-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.fan.state.target|
|**Permissions**|Paired Write, Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Manual”<br>1<br>”Auto”|


##### 9.110 Target Tilt Angle

This characteristic describes the target angle of slats for accessories such as windows, fans, portable heater/coolers etc.


This characteristic requires iOS 10.3 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


222


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|000000C2-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.tilt.target|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|int|
|**Minimum Value**|-90|
|**Maximum Value**|90|
|**Step Value**|1|
|**Unit**|arcdegrees|


##### 9.111 Target Heater Cooler State


This characteristic describes the target state of heater cooler.


_`Heat or Cool`_ state must only be included for accessories which include both a cooler and a heater. _`Heat or Cool`_ state
(see ”9.111 Target Heater Cooler State” (page 223)) implies that the accessory will always try to maintain the ”9.35 Current
Temperature” (page 175) between ”9.42 Heating Threshold Temperature” (page 178) and ”9.20 Cooling Threshold Temperature”
(page 167) and if the ”9.35 Current Temperature” (page 175) increases above/falls below the threshold temperatures the equipment will start heating or cooling respectively.


In _`Heat`_ state the accessory will start heating if the current temperature is below the ”9.42 Heating Threshold Temperature”
(page 178). In _`Cool`_ state the accessory will start cooling if the current temperature is greater than the ”9.20 Cooling Threshold
Temperature” (page 167).


This characteristic requires iOS 11 or later.

##### 9.112 Set Duration


This characteristic describes the set duration. For a ”8.43 Valve” (page 155) this duration defines how long a valve should be set
to ʼIn Useʼ. Once the valve is ʼIn Useʼ, any changes to this characteristic take affect in the next operation when the ”8.43 Valve”
(page 155) is _`Active`_ .


This duration is defined in seconds.


This characteristic requires iOS 11.2 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


223


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|000000D3-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.set-duration|
|**Permissions**|Paired Write, Paired Read, Notify|
|**Format**|uint32|
|**Minimum Value**|0|
|**Maximum Value**|3600|
|**Step Value**|1|


##### 9.113 Target Control Supported Configuration


This characteristic allows the accessory to indicate the configuration it supports and is encoded as a list of TLV8 tuples.


This characteristic requires iOS 12 or later.

|Property|Value|
|---|---|
|**UUID**|00000123-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.supported-target-configuration|
|**Permissions**|Paired Read|
|**Format**|tlv8|



The value of this characteristic is a TLV8-encoded list of supported parameters. The list of types for the TLVs are as follows:


**Table 9-29:** Target Control Commands TLV8 Definition

|Type|Name|Format|Description|
|---|---|---|---|
|1|Maximum Targets|1|Maximum number of targets that can be supported by this acces-<br>sory. If a tuple of this TLV type is omitted, it is assumed that the<br>accessory supports 16 targets.|
|2|Ticks Per Second|8|Resolution of the timestamp sent in the button value characteristic.<br>The value is encoded as a uint64 value.|
|3|Supported Button Configuration|N|Configuration of the supported buttons - The value is a TLV8-<br>encoded list.|
|4|Type|1|Must be set to 1 if the accessory is implemented as a hardware en-<br>tity. Siri is only allowed for a hardware entity. See ”12.3 Additional<br>Security Requirements” (page 251) for more details.|



The Supported Button Configuration describes multiple buttons encoded in the value. The configuration of a button starts with
a Button ID TLV and ends at the end of the TLV value or the next Button ID TLV.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


224


9. Apple-defined Characteristics


The Supported Button Configuration is expressed as a tlv8 encoding with the following types:


**Table 9-30:** Supported Button Configuration Format TLV8 Definition

|Type|Name|Format|Description|
|---|---|---|---|
|1|Button ID|1|ID of a button; a value of 0 is invalid. When a TLV of this type is encountered, configura-<br>tion of a new button is being described.|
|2|Button Type|2|Type of button:<br>0 - Undefined<br>1 - Menu<br>2 - Play/Pause<br>3 - TV/Home<br>4 - Select<br>5 - Arrow Up<br>6 - Arrow Right<br>7 - Arrow Down<br>8 - Arrow Left<br>9 - Volume Up<br>10 - Volume Down<br>11 - Siri<br>12 - Power<br>13 - Generic|


##### 9.114 Target Control List


This HAP characteristic allows a controller to manage the association of targets with the accessory. This characteristic must
support write response and is implemented as a control point characteristic with the write value indicating the type of operation
and the result expected in the write response. The write response must include all the target configurations present on the
accessory after the write operation. The accessory must store the configuration from the Target Control List in its persistent
store and this configuration must not be erased on reboot of the accessory. The configuration must be erased on factory reset
of the accessory and when the last admin pairing is removed from the accessory.


Only admin controllers are allowed to perform any operations on this characteristic. Any read/writes to this characteristic by non
admin controllers must result in error -70401 (Insufficient Privileges).


This characteristic requires iOS 12 or later.

|Property|Value|
|---|---|
|**UUID**|00000124-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.target-list|
|**Permissions**|Paired Write, Paired Read, Write Response|
|**Format**|tlv8|



The write value of this characteristic is a tlv8 encoded with the following parameters:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


225


9. Apple-defined Characteristics


**Table 9-31:** Target Control List TLV8 Definition

|Type|Name|Format|Description|
|---|---|---|---|
|1|Operation|1|Operation for the control point:<br>0 - Undefined<br>1 - List; response contains the current configuration<br>2 - Add; response contains the updated configuration<br>3 - Remove; response contains the updated configuration<br>4 - Reset; response contains no value<br>5 - Update; response contains the updated configuration|
|2|Target Configuration|tlv8|Configuration for a specific target. Value is tlv8 encoded. Not needed in the<br>write value for_` List`_ and_` Reset`_ operations.|



The Target Configuration describes multiple targets encoded in the value. The configuration of a target starts with a Target
Identifier TLV and ends at the end of the TLV value or the next Target Identifier TLV. The Target Configuration is expressed as a
tlv8 encoding with the following types:


**Table 9-32:** Target Configuration TLV8 Definition

|Type|Name|Format|Description|
|---|---|---|---|
|1|Target Identifier|4|Identifier of the target; value is a uint32. 0 indicates an invalid Target or that<br>no Target is currently selected (e.g., the target controller is controlling a non-<br>HomeKit entity). When a TLV of this type is encountered, configuration of a<br>new target is being described.|
|2|Target Name|N|Name of the target;value is a UTF8 string.|
|3|Target Category|2|Category of the target; value is a uint16|
|4|Button Configuration|tlv8|Configuration of an enabled button; value is encoded as a TLV8.<br>One instance present per button enabled.|



The Target Category has the following enumerations:


**Table 9-33:** Target Category Enumerations

|Target Category|Target Description|
|---|---|
|_`0`_|Undefined|
|_`24`_|Apple TV|



The Button Configuration describes multiple buttons ecoded in the value. The configuration of a button starts with a Button ID
TLV and ends at the end of the TLV value or the next Button ID TLV.


The Button Configuration is expressed as a tlv8 encoding with the following types:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


226


9. Apple-defined Characteristics


**Table 9-34:** Button Configuration TLV8 Definition

|Type|Name|Format|Description|
|---|---|---|---|
|1|Button ID|1|ID of button; a value of 0 is invalid.<br>When a TLV of this type is encountered, configuration of a new button is being de-<br>scribed.|
|2|Button Type|2|Type of button. May be optionally present.|
|3|Button Name|N|Name of the Button - value is a UTF8 string.<br>May be optionally present. If present, accessory must use this name instead of the name<br>derived from the button type.|


##### 9.115 Target Horizontal Tilt Angle


This characteristic describes the target angle of horizontal slats for accessories such as windows, fans, portable heater/coolers
etc.


This characteristic requires iOS 9 or later.

|Property|Value|
|---|---|
|**UUID**|0000007B-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.horizontal-tilt.target|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|int|
|**Minimum Value**|-90|
|**Maximum Value**|90|
|**Step Value**|1|
|**Unit**|arcdegrees|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


227


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|000000B2-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.heater-cooler.state.target|
|**Permissions**|Paired Write, Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|2|
|**Step Value**|1|
|**Valid Values**|0<br>”Heat or Cool”<br>1<br>”Heat”<br>2<br>”Cool”|


##### 9.116 Target Humidifier Dehumidifier State

This characteristic describes the target state of a humidifier or/and a dehumidifier.


_`Humidifier or Dehumidifier`_ state must only be included for accessories which include both a humidifier and a dehumidifier. _`Humidifier or Dehumidifier`_ state (see ”9.116 Target Humidifier Dehumidifier State” (page 228)) implies that the
accessory will always try to maintain the ”9.34 Current Relative Humidity” (page 174) between ”9.77 Relative Humidity Humidifier Threshold” (page 195) and ”9.76 Relative Humidity Dehumidifier Threshold” (page 194) and if the ”9.34 Current Relative
Humidity” (page 174) increases above/falls below the threshold relative humidity the equipment will start dehumidifying or humidifying respectively.


In _`Humidifier`_ state the accessory will start humidifying if the current humidity is below the ”9.77 Relative Humidity Humidifier
Threshold” (page 195). In _`Dehumidifier`_ mode the accessory will start dehumidifying if the current humidity is greater than
the ”9.76 Relative Humidity Dehumidifier Threshold” (page 194).


This characteristic requires iOS 11 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


228


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|000000B4-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.humidifier-dehumidifier.state.target|
|**Permissions**|Paired Read, Notify, Paired Write|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|2|
|**Step Value**|1|
|**Valid Values**|0<br>”Humidifier or Dehumidifier”<br>1<br>”Humidifier”<br>2<br>”Dehumidifier”|


##### 9.117 Target Position

This characteristic describes the target position of accessories. This characteristic can be used with doors, windows, awnings
or window coverings. For windows and doors, a value of 0 indicates that a window (or door) is fully closed while a value of 100
indicates a fully open position. For blinds/shades/awnings, a value of 0 indicates a position that permits the least light and a value
of 100 indicates a position that allows most light.


This characteristic requires iOS 9 or later.

|Property|Value|
|---|---|
|**UUID**|0000007C-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.position.target|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|100|
|**Step Value**|1|
|**Unit**|percentage|


##### 9.118 Target Door State


This characteristic describes the target state of a door.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


229


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|00000032-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.door-state.target|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Open”<br>1<br>”Closed”<br>2-255<br>”Reserved”|


##### 9.119 Target Heating Cooling State

This characteristic describes the target mode of an accessory that supports heating/cooling, e.g. a thermostat.





|Property|Value|
|---|---|
|**UUID**|00000033-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.heating-cooling.target|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|3|
|**Step Value**|1|
|**Valid Values**|0<br>”Off”<br>1<br>”Heat. If the current temperature is below the target temperature then<br>turn on heating.”<br>2<br>”Cool. If the current temperature is above the target temperature then<br>turn on cooling.”<br>3<br>”Auto. Turn on heating or cooling to maintain temperature within the<br>heating and cooling threshold of the target temperature.”<br>4-255<br>”Reserved”|


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


230


9. Apple-defined Characteristics

##### 9.120 Target Relative Humidity


This characteristic describes the target relative humidity that the accessory is actively attempting to reach. The value is expressed
as a percentage (%).

|Property|Value|
|---|---|
|**UUID**|00000034-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.relative-humidity.target|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|100|
|**Step Value**|1|
|**Unit**|percentage|


##### 9.121 Target Temperature


This characteristic describes the target temperature in Celsius that the accessory is actively attempting to reach. For example, a
thermostat cooling a room to 75 degrees Fahrenheit would set the target temperature value to 23.9 degrees Celsius.

|Property|Value|
|---|---|
|**UUID**|00000035-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.temperature.target|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|float|
|**Minimum Value**|10.0|
|**Maximum Value**|38.0|
|**Step Value**|0.1|
|**Unit**|celsius|


##### 9.122 Temperature Display Units


This characteristic describes units of temperature used for presentation purposes (e.g. the units of temperature displayed on the
screen).


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


231


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|00000036-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.temperature.units|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|1|
|**Step Value**|1|
|**Valid Values**|0<br>”Celsius”<br>1<br>”Fahrenheit”<br>2-255<br>”Reserved”|


##### 9.123 Target Vertical Tilt Angle

This characteristic describes the target angle of vertical slats for accessories such as windows, fans, portable heater/coolers etc.


This characteristic requires iOS 9 or later.

|Property|Value|
|---|---|
|**UUID**|0000007D-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.vertical-tilt.target|
|**Permissions**|Paired Read, Paired Write, Notify|
|**Format**|int|
|**Minimum Value**|-90|
|**Maximum Value**|90|
|**Step Value**|1|
|**Unit**|arcdegrees|


##### 9.124 Valve Type


This characteristic describes the type of valve.


This characteristic requires iOS 11.2 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


232


9. Apple-defined Characteristics








|Property|Value|
|---|---|
|**UUID**|000000D5-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.valve-type|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|3|
|**Step Value**|1|
|**Valid Values**|0<br>”Generic valve”<br>1<br>”Irrigation”<br>2<br>”Shower head”<br>3<br>”Water faucet”<br>4-255<br>”Reserved”|


##### 9.125 Version

This characteristic contains a version string.

|Property|Value|
|---|---|
|**UUID**|00000037-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.version|
|**Permissions**|Paired Read|
|**Format**|string|
|**Maximum Length**|64|


##### 9.126 VOC Density


This characteristic indicates the current volatile organic compound density in micrograms/m [3] .


This characteristic requires iOS 10.3 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


233


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|000000C8-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.density.voc|
|**Permissions**|Paired Read, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|1000|


##### 9.127 Volume


A Volume characteristic allows the control of input or output volume of an audio input or output accessory respectively.


The value of this characteristic indicates the percentage of the maximum volume supported by the service.


If the audio RTP service can support controlling the volume, this characteristic must support Paired Write permission as well.


This characteristic requires iOS 10 or later.

|Property|Value|
|---|---|
|**UUID**|00000119-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.volume|
|**Permissions**|Paired Write, Paired Read, Notify|
|**Format**|uint8|
|**Minimum Value**|0|
|**Maximum Value**|100|
|**Step Value**|1|
|**Unit**|percentage|


##### 9.128 Water Level


This characteristic describes the current water level.


This characteristic requires iOS 11 or later.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


234


9. Apple-defined Characteristics

|Property|Value|
|---|---|
|**UUID**|000000B5-0000-1000-8000-0026BB765291|
|**Type**|public.hap.characteristic.water-level|
|**Permissions**|Paired Read, Notify|
|**Format**|float|
|**Minimum Value**|0|
|**Maximum Value**|100|
|**Step Value**|1|
|**Unit**|percentage|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


235


### 10 Apple-defined Profiles

##### 10.1 Overview

An Apple-defined profile is comprised of Apple-defined characteristics and Apple-defined services. A custom profile may be
comprised of custom characteristics, Apple-defined characteristics, and custom services. Accessories must use Apple-defined
characteristics to expose functionality of the accessory if they are available, e.g. a temperature sensor must use the Appledefined ”9.35 Current Temperature” (page 175) characteristic rather than defining its own custom characteristic to expose the
same functionality.

##### 10.2 Lock


The purpose of the HomeKit Accessory Lock Profile is to provide a set of standard services and characteristics to describe and
interact with locks, such as a door lock, or lock on an automobile. The physical equivalent of the functionality this service provides
is turning a key inside a lock after it has been inserted. Services and characteristics contained herein only cover lock interaction.
The services and characteristics defined in this document are designed to be used on both IP and Bluetooth Low Energy devices,
unless otherwise noted. All transactions are secured with HAP session security, which is described in the ”7 HomeKit Accessory
Protocol for Bluetooth LE Accessories” (page 88).


10.2.1 Lock Mechanism Service


The ”8.26 Lock Mechanism” (page 148) service is a primary service, designed to expose and control the physical lock mechanism
on an accessory. Implementation of this service is mandatory.


An implementation should not add vendor-specific characteristics to the Lock Mechanism Service because doing so will increase
characteristic discovery time due to additional protocol transactions.


10.2.2 Lock Management Service


The ”8.25 Lock Management” (page 148) service is a secondary service, designed to expose deeper interaction with a Lock
accessory. Implementation of this service is mandatory. However, portions of this service are optional.


An implementation may add vendor-specific characteristics to the Lock Management Service but doing so may increase characteristic discovery time due to additional protocol transactions.


10.2.2.1 Control Point Characteristic Commands


The ”9.51 Lock Control Point” (page 183) characteristic accepts the following TLV8 commands:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


236


10. Apple-defined Profiles


**Table 10-1:** Lock Control Point Characteristic Commands TLV8 Definition

|Type|Name|Format|Description|
|---|---|---|---|
|0x00|readLogsFromTime|int|Read the logs starting at the value, which is in seconds since epoch time. A zero-<br>length value will read all logs since the last wipe.|
|0x02|clearLogs|int|Clear the Lockʼs logs.|
|0x03|setCurrentTime|int|Set the Lockʼs current time, defined as seconds since epoch time.|



10.2.2.2 Version Characteristic


The version of the Lock Profile that the accessory supports, as a string. For example, if the version of the supported Apple Lock
Profile is ”2.3”, that value should be returned when the characteristic is read. Inclusion of this characteristic is mandatory.


The value of this characteristic must be the string “1.0”.


10.2.2.3 Logs Characteristic Response Format


The ”9.57 Logs” (page 186) characteristic returns a list of logs provided in the following TLV8 format, with a separator in between
each log entry.


**Table 10-2:** Logs Characteristic Response Format TLV8 Definition

|Type|Name|Format|Description|
|---|---|---|---|
|0x01|accessor|string|The user name that accessed the lock (provided by the HomeKit Accessory Pairing<br>Profile).|
|0x02|time|int|The time the accessor accessed the Lock, defined as seconds since epoch time.|
|0x03|action|int|The action the accessor took when accessing the Lock Mechanism.<br>Bits:<br>1<br>”Lock mechanism state read”<br>2<br>”Lock Mechanism Action occurred”<br>3<br>”All logs cleared”<br>6-8<br>”Reserved”|
|0x04|vendorSpecific|data|Vendor-specific log elements. Limited to 255 bytes.|
|0x05|separator|none|Empty element to separate groups of items within a single payload.|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


237


### 11 IP Cameras

##### 11.1 Overview

This section specifies the HAP-based services, characteristics, and communication protocol for IP camera accessories that support RTP streaming of audio/video.

##### 11.2 Requirements


11.2.1 Streaming Requirements


RTP for media transport


[• RTP - A Transport Protocol for Real-Time Applications - RFC 3550](http://tools.ietf.org/html/rfc3550)


[• RTP Profile for Audio and Video Conferences with Minimal Control - RFC 3551](http://tools.ietf.org/html/rfc3551)


[• Extended RTP Profile for Real-time Transport Control Protocol (RTCP)-Based Feedback (RTP/AVPF) - RFC 4585](http://tools.ietf.org/html/rfc4585)


[• Codec Control Messages in the RTP Audio-Visual Profile with Feedback (AVPF) - RFC 5104](http://tools.ietf.org/html/rfc5104)


[• Multiplexing RTP Data and Control Packets on a Single Port - RFC 5761](http://tools.ietf.org/html/rfc5761)


[• RTP Payload Format for H.264 Video - RFC6184](http://tools.ietf.org/html/rfc6184)


[• [3GPPTS 26.114] ”Coordination of Video Orientation” Section 7.4.5](http://www.etsi.org/deliver/etsi_ts/126100_126199/126114/12.08.00_60/ts_126114v120800p.pdf)


[• RTP Payload Format for Opus Speech and Audio Codec RFC 7587 with an exception that Opus audio RTP Timestamp](https://tools.ietf.org/rfc/rfc7587.txt)
[shall be based on RFC 3550](https://tools.ietf.org/html/rfc3550)


[• The Secure Real-time Transport Protocol (SRTP) - RFC 3711](http://tools.ietf.org/html/rfc3711)


[• The Use of AES-192 and AES-256 in Secure RTP - RFS 6188](http://tools.ietf.org/html/rfc6188)


[• RTCP Sender Report for both Audio and Video must adhere to Section 6.4.1 of RFC 3550. Both Audio and Video NTP](https://tools.ietf.org/html/rfc3550)
should be derived from the same ”wall clock”.


   - Audio RTP timestamp reflects the sampling instant of the first octet in the RTP data packet and must adhere to section
[5.1 of RFC 3550 for all codecs including OPUS](https://tools.ietf.org/html/rfc3550)


[• Video RTP timestamp is set to the sampling timestamp of the content and must adhere to section 5.1 of RFC 6184](https://tools.ietf.org/html/rfc6184)


11.2.2 Optional Requirements


The following requirements may be supported by IP camera accessories:


   - Multiple audio/video sources need to be published as different accessories


   - Support for accessory to publish supported audio output decode formats:


**–** The assumption for now is that this is the same as the audio codec used for sourcing input audio


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


238


11. IP Cameras

##### 11.3 Service Definitions


11.3.1 IP Camera


The following services are required to support IP camera using HomeKit Accessory Protocol:


   - ”8.6 Camera RTP Stream Management” (page 137) services describe and allow configuration/control of at least two RTP
session for streaming audio and video from the accessory


   - ”8.27 Microphone” (page 149) service provides control over audio sourcing


Optionally, an IP camera accessory can support additional services such as:


   - ”8.36 Speaker” (page 152) service for two-way audio


11.3.2 Video Doorbell Profile


This service describes the features of a video doorbell.


   - ”8.12 Doorbell” (page 140)


   - Video Doorbell Secondary Services:


The following secondary services are designed to expose the IP camera functionality of a video doorbell:


**Table 11-1:** Video Doorbell Secondary Services

|Service|Required or Optional|
|---|---|
|”8.6 Camera RTP Stream Management” (page 137)|Required|
|”8.36 Speaker” (page 152)|Required|
|”8.27 Microphone” (page 149)|Required|


##### 11.4 RTP Configuration


11.4.1 RTCP Based Feedback


[The IP Camera must support the reception of following RTCP-FB messages defined in RFC 4585 and RFC 5104 in addition to](https://tools.ietf.org/html/rfc4585)
[the regular RTCP reports mentioned in RFC 3550.](https://www.ietf.org/rfc/rfc3550.txt)


   - FIR - Upon receiving FIR, IP camera must send a decoder refresh point at the earliest opportunity. See section 3.5.1 of

[RFC 5104 for more details.](https://tools.ietf.org/html/rfc5104)


[• PLI - IP Camera must calculate Round trip time (RTT) using the incoming RTCP reports as detailed in RFC 3550. The IP](https://www.ietf.org/rfc/rfc3550.txt)
[Camera shall adhere to the following behavior when handling incoming PLI RFC 4585 requests,](https://tools.ietf.org/html/rfc4585)


**–** If a PLI is received after 2 x RTT from when the last key frame was sent, the IP Camera must respond with a key
frame at the earliest opportunity. In doing so, the subsequent periodic keyframes should be delayed by ”keyframe
interval”.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


239


11. IP Cameras


**–** If a PLI is received after 2 x RTT along with TMMBR as part of compound RTCP packet, the IP Camera shall adjust
the bitrate first and then generate the key frame at the newly requested bitrate.


**–** If a PLI is received within 2 x RTT from when the last keyframe was sent, the IP Camera must ignore the PLI request.
The next periodic keyframe shall be sent as usual after the keyframe interval elapses.


IP Camera must implement the PLI Handling as described in the below figure IP Camera - PLI Handling


   - TMMBR/TMMBN - Upon receiving TMMBR, IP camera must cap its video bitrate to the bitrate requested in the TMMBR.
Upon receiving the TMMBR, IP camera must acknowledge the receipt for TMMBR by sending a TMMBN immediately. See
[section 3.5.4 of RFC 5104 for more details.](https://tools.ietf.org/html/rfc5104)


**–** TMMBR must be assigned a higher priority than PLI in case they are compounded in a single RTCP packet


**–** When the IP camera sends TMMBN upon receiving a TMMBR, it must reset its RTCP send time and the next RTCP
regular report should be sent after one RTCP interval period.


[The IP Camera should support the reception of following RTCP-FB messages defined in RFC 5104.](https://tools.ietf.org/html/rfc5104)


   - TSTR - Upon receiving TSTR, IP camera should adjust its temporal-spatial trade-off to what is requested in TSTR.


   - TSTN -Upon receiving the TSTR, IP camera should acknowledge the receipt for TSTR by sending a TSTN in the next RTCP
interval.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


240


11. IP Cameras

















Camera sends periodic Key frames Camera sends Key frame in response to Camera ignores a PLI as it came
based on KFI. PLI. Subsequent key frame is adjusted within 2 * RTT since the last key frame

based on KFI. sent.


RTT - Round Trip Time calculated as per RFC 3550 using RTCP reports
KFI - Key Frame Interval
PLI - Picture Loss Indication (RTCP-FB)















When PLI is sent along with a TMMBR
as part of compound RTCP packet,
Camera adjust the bitrate first and then
a key frame is generated at the newly
requested bitrate.



Camera ignores a subsequent PLI as it
came within 2 * RTT since the last key
frame sent.


**Figure 11-1:** IP Camera - PLI Handling



Variable delay in network can cause two
PLIs to come back to back. Camera
ignores second PLI that arrives before
sending a key frame for the first PLI.



11.4.2 RTP Extension for Coordination of Video Orientation


If the IP Camera can support rotation while streaming, it must support RTP extension for Coordination of Video Orientation [3GPP
TS 26.114] for video RTP.


An IP Camera which supports the RTP extension for Co-ordination of Video Orientation, must:


   - Add the payload bytes as defined in [3GPP TS 26.114 - Co-ordination of Video Orientation] onto the last RTP packet in


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


241


11. IP Cameras


each group of packets which make up a key frame


   - Add the payload bytes onto the last RTP packet in each group of packets which make up another type of frame (e.g. a
P-Frame) only if the current value is different from the previous value sent.


11.4.3 Reconfiguring a Streaming Session


The controller may issue a “Reconfigure Streaming Session” command to change the parameters of the video stream. The
controller will not issue this command to change the parameters of the audio stream.


When the controller issues this command, the IP camera must reconfigure the attributes of the stream without affecting the RTP
session.


   - The RTP stream must not be restarted


**–** The RTP packet that is generated after the reconfigure command is executed at the IP camera (the next RTP packet)
will be an IDR packet at a different resolution


  - The sequence numbers must not be reset


**–** The sequence number of the next RTP packet will increment by one


   - The time-stamp of the next RTP packet may account for the time it took for this next RTP packet to be generated


Example of a Reconfigure Streaming Session Command:

```
Selected Stream Configuration:
     {
         SessionControl
{
       controlCommand = Reconfigure
       sessionID = 567FAAB5-BBB7-46FF-914A-E56B474FCDB4
}
videoParameters =
        {
             attributes =
             {
               imageWidth = 320
                imageHeight = 240
             }
             rtpParameters =
             {
                maximumBandwidth = 422
minimumRTCPInterval = 1
frameRate = 15
             }
         }
}

##### 11.5 Image Snapshot

```

An Image snapshot feature allows a controller to request the IP Camera accessory to capture and retrieve a static image from the
camera.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


242


11. IP Cameras


When a controller sends an HTTP POST request with the desired image-width and image-height in the body the accessory must
run the resource routine:


POST /resource HTTP/1.1


Example of a snapshot request in POST:

```
/resource
aid: <number> (Optional)
resource-type : image
image-width : <number>
image-height: <number>

```

The IP camera must set the MIMEType in the HTTP response to image and must provide the snapshot in JPEG format.


The IP Camera must return a snapshot only in the resolution that the controller requests for.


Note: aid field is optional and used to identify the camera that the snapshot request targets when applicable.

##### 11.6 IP Camera Streaming Procedure


The sequence diagram below indicates the sequence of steps that a controller will perform to set up a streaming session with
the IP camera accessory. A secure (pair-verified) session must be established before a streaming session can be established.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


243


11. IP Cameras

























**Figure 11-2:** IP Camera Streaming Procedure


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


244


11. IP Cameras

##### 11.7 Multiple Camera RTP Stream Management


The IP camera must advertise a unique instance of the Camera RTP Stream Management Service for each of the Audio and Video
stream configurations that it can simultaneously stream to iOS controllers.


   - One stream must support a resolution of 1080p


   - The minimum advertised resolution for any stream must be 720p


   - The minimum supported frame rate for any stream must be 24fps, the minimum recommended frame rate for any stream
is 30fps


   - The IP camera must support at least two simultaneous streams viewable at two different controllers. Each stream configuration must include the video attributes TLVs for the highest supported resolution as well as all the lower resolutions
that the camera can support at any given instance


   - Instances of the Camera RTP Stream Management services must remain static through the lifetime of the IP camera.
Services can only be added or removed via a firmware update to the accessory

##### 11.8 Media Codecs


11.8.1 Mandatory Video RTP Service Settings


An IP camera accessory must support the following settings for the video RTP service:


  - Codec type: H.264


**–** Profile ID: Main Profile, Level: 4


  - SPS PPS must use STAP-A fragmentation


   - Video resolutions


**Table 11-2:** Video Resolutions





|Aspect Ratio|Resolution|
|---|---|
|16ԃ9|1920x1080 (1080p)<br>1280x720 (720p)<br>640x360<br>480x270<br>320x180|
|4ԃ3|1280x960<br>1024x768 (XGA)<br>640x480 (VGA)<br>480x360 (HVGA)<br>320x240 (QVGA)|


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


245


11. IP Cameras


   - Default MTU for Video RTP Stream


**–** The IP camera must use the following values as default MTUʼs for Video RTP streams

       - [IPv4 - 1378 bytes]

       - [IPv6 - 1228 bytes]

**–** The controller may request the camera to choose a different MTU in the Selected RTP Stream Configuration characteristic


   - The minimum keyframe interval shall be 5 seconds


11.8.2 Mandatory Audio RTP service settings


   - An IP camera must support AAC-ELD or Opus at 16K or 24K sample rates.


   - AAC-ELD or Opus must be supported in Variable Bit Rate mode.


   - The block size for AAC-ELD must be 480 samples


11.8.3 Mandatory RTP Profile


[An IP camera must support SAVPF RFC 5124](https://tools.ietf.org/html/rfc5124)

##### 11.9 Media Transport


[Audio and video packets are delivered using RFC 3550. The RTP payload format is dependent on the codecs, and is described](http://tools.ietf.org/html/rfc3550)
[through the appropriate IETF documents (e.g. RFC 6184 for H.264, RFC 6716 for Opus and RFC 3640 - Section.3.3.6 - High](http://tools.ietf.org/html/rfc6184)
[Bit-rate AAC for AAC-ELD).](https://tools.ietf.org/html/rfc3640#section-3.3.6)


[RTP and RTCP packets are multiplexed over a single port RFC 5761. Separate ports are used to stream audio and video. The RTP](https://tools.ietf.org/html/rfc5761)
port number must be >= 1024.


[SRTP RFC 3711 must be used to provide media security. The SRTP crypto-suite of the service is indicated by the SRTP Crypto-](http://tools.ietf.org/html/rfc3711)
Suite characteristic. The SRTP master key and master salt are exchanged when setting up a stream through the Session Start
characteristic.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


246


### 12 Remotes for Apple TV

##### 12.1 Button Control Requirements

Any accessory which controls an Apple TV must advertise the following additional services:


   - ”8.40 Target Control Management” (page 154)


   - ”8.39 Target Control” (page 154)

##### 12.2 Siri Control Requirements


This section specifies the requirements for accessories which have a voice input button to control Apple TV.


The accessory must advertise the following additional services to support Siri:


   - ”8.33 Siri” (page 151)


  - ”8.10 Data Stream Transport Management” (page 139)


  - ”8.4 Audio Stream Management” (page 136)


When the user holds down this button, the accessory sends an audio stream to the active target. When the user releases the
button, the target processes the full Siri request.


The controller creates a HomeKit Data Stream (HDS, see ”6.10 HomeKit Data Stream” (page 80)) connection for each target
configuration received by the accessory.


When voice input button is pressed, the accessory encodes the audio and sends it over the HomeKit Data Stream.


Siri audio must be sent using the following codec and parameters:


   - Opus format (CELT encoding preferred)


   - Variable Bitrate


   - 16kHz sampling rate


  - 20ms packet time


12.2.1 Packet Formats


12.2.1.1 Start


The accessory opens a new voice stream using the open request. The header should use _`dataSend`_ as the protocol and _`open`_
as the topic.


The request has the following message fields:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


247


12. Remotes for Apple TV


**Table 12-1:** Request Properties

|Key|Type|Description|
|---|---|---|
|_`target`_|string|_`controller`_ - to signify the direction of the send|
|_`type`_|string|_`audio.siri`_ - the type of the stream|



The response has the following message fields, if successful:


**Table 12-2:** Response Properties

|Key|Type|Description|
|---|---|---|
|_`streamId`_|int64|used to identify this stream; chosen by the controller|



This packet is sent by the accessory to signal that it wants to being a new transfer of audio. If the accessory does not receive a
response within 5 seconds, the accessory should treat the stream as a failed setup. If the accessory receives a response after 5
seconds (but before the 10-second limit), then it must close the stream without sending any data (and use _`timed out`_ as the
reason).


If the controller accepts the stream, then the response includes a stream identifier that must be included in all other _`dataSend`_
messages for this stream. The accessory can immediately start sending audio packets using the _`dataSend.data packet`_ .


The controller must choose a stream identifier that is unambiguous and that does not conflict with any other active or recentlyactive stream (if there are any).


12.2.1.2 Binary Data


The accessory sends voice packets using the data event. The header should use _`dataSend`_ as the protocol and _`data`_ as the
topic.


The event has the following message fields:


**Table 12-3:** Event Properties

|Key|Type|Description|
|---|---|---|
|_`streamId`_|int64|Same identifier used in the_` dataSend.open`_|
|_`packets`_|array|Array of dictionaries|
|_`endOfStream`_|boolean|(optional) Indicates the final frame; set to true.|



Packet Dictionary:


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


248


12. Remotes for Apple TV


**Table 12-4:** Packet Dictionary

|Key|Type|Description|
|---|---|---|
|_`data`_|Bytes|Packet data|
|_`metadata`_|Dictionary|Meta data for the packet (Optional. This is required when type is audio.siri.)|



For Siri audio data, metadata is defined as:


**Table 12-5:** Siri Audio Data

|Key|Type|Description|
|---|---|---|
|_`rms`_|Float|The<br>RMS<br>value<br>is<br>set<br>to<br>each<br>Opus<br>frame<br>(320<br>samples,<br>or<br>20<br>ms).<br>The<br>following<br>formula<br>computes<br>the<br>RMS<br>value:<br>_RMS_ =_ sqrt_(((_s_0)2 + (_s_1)2_..._ + (_s_319)2)/320)|
|_`sequenceNumber`_|Int64|Integer that starts at 0 and counts up in each frame. Frames must still be delivered<br>in order without gaps.|



This packet is sent by the accessory to deliver the audio to the controller. The accessory is free to send any number of bytes in
each frame, up to the frame maximum.


The packets field is required, but it is allowed to be zero-length even if more data will be delivered in later packets. For example,
this packet may be used to send one of the other flags even if it does not yet have a new fragment to deliver. The _`endOfStream`_
field indicates that the bulk transfer is complete and no further data will be delivered. The final frame must still contain the packets
field, which will contain the last fragment of data in the transmission. If all data had already been sent in prior frames, it must still
be present but will have zero-elements.


12.2.1.3 Acknowledgement


The controller will acknowledge the stream with this event. The header should use _`dataSend`_ as the protocol and _`ack`_ as the
topic.


The event has the following message fields:


**Table 12-6:** Acknowledgement Event

|Key|Type|Description|
|---|---|---|
|_`streamId`_|int64|Same identifier used in the_` dataSend.open`_|
|_`endOfStream`_|boolean|Indicates acknowledgement of the_` endOfStream`_ flag. Set to true.|



This packet must be sent by the controller after it has received the final frame with the _`endOfStream`_ flag set. This is an indication
to the accessory that the transfer has been accepted and can be considered successful.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


249


12. Remotes for Apple TV


12.2.1.4 Close


This event closes the stream. The header should use _`dataSend`_ as the protocol and _`close`_ as the topic.


The event has the following message fields:


**Table 12-7:** Close Event

|Key|Type|Description|
|---|---|---|
|_`streamId`_|int64|Same identifier used in the_` dataSend.open`_|
|_`reason`_|int64|Example reasons:<br>0 - Normal - Normal Close<br>1 - Not Allowed - Controller will not allow the Accessory to send this transfer<br>2 - Busy - Controller cannot accept this transfer right now<br>3 - Cancelled - Accessory will not finish the transfer<br>4 - Unsupported - Controller does not support this stream type.<br>5 - Unexpected Failure - Some other protocol error occurred and the stream has failed.<br>6 - Timeout - Accessory could not start the session.|



The accessory must send this packet to the controller in order to balance the _`open`_ operation. After the accessory sends or
receives a close event, it must not attempt to send any further packets using this stream identifier. After receiving this packet,
the controller must not attempt to send any other packets (eg, cancel) with this identifier. If either side receives a packet after
this one using the same identifier, it must ignore it.


If the stream was completed successfully, the accessory must send this packet after receiving the final stream acknowledgement
from the controller.


The accessory may send this packet to the controller to indicate that this transmission is being cancelled and the data received
is not considered complete. This could be due to an irrecoverable error on the accessory, but can also represent the user doing
something that cancels the operation.


The controller may send this packet to the accessory to indicate that it is not interested in this transmission and that it will not be
used.


12.2.1.5 Target Control Identifier


If the accessory is capable of doing Siri input, then the controller will send an advertisement of its Target Control identifier. The
Accessory can use this identifier to know whicn Data Stream connection matches the AppleTV it intends to send Siri audio to.


The protocol is _`targetControl`_ and event topic is _`whoami`_


The event has the following message fields:


**Table 12-8:** Target Control Event

|Key|Type|Description|
|---|---|---|
|_`identifier`_|uint32|The Target Control identifier|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


250


12. Remotes for Apple TV

##### 12.3 Additional Security Requirements


   - Button press events from remote accessories must not be stored on servers.


[• Any servers used to relay button press events from the remote accessory to a HomeKit bridge must be App Transport](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/uid/TP40009251-SW57)
[Security compliant.](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/uid/TP40009251-SW57)


   - Siri for Apple TV control is allowed for remote accessories implemented as a hardware entity (see type in ”9.113 Target
Control Supported Configuration” (page 224)) only.


   - A remote accessory implemented as a hardware entity (see type in ”9.113 Target Control Supported Configuration”

(page 224)) must send Siri audio (if applicable) and button press events over the local network only and not through
a server.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


251


### 13 Accessory Categories

This chapter provides a list supported accessory categories in HomeKit.

|Value|Accessory Category|
|---|---|
|1|Other|
|2|Bridges|
|3|Fans|
|4|Garage Door Openers *|
|5|Lighting|
|6|Locks *|
|7|Outlets|
|8|Switches|
|9|Thermostats|
|10|Sensors|
|11|Security Systems *|
|12|Doors *|
|13|Windows *|
|14|Window Coverings|
|15|Programmable Switches|
|16|Reserved|
|17|IP Cameras *|
|18|Video Doorbells *|
|19|Air Purifiers|
|20|Heaters|
|21|Air Conditioners|
|22|Humidifiers|
|23|Dehumidifiers|
|24-27|Reserved|
|28|Sprinklers|
|29|Faucets|
|30|Shower Systems|
|31|Reserved|
|32|Remotes|
|32+|Reserved|



2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


252


13. Accessory Categories


Note: An accessory with support for multiple categories should advertise the primary category. An accessory for which a primary
category cannot be determined or the primary category isnʼt among the well defined categories (2-9) falls in the Other category.
*: These accessory categories must use programmable tags if they support NFC.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


253


### 14 Appendix

##### 14.1 TLVs

A TLV8 data structure is a _type-length-value_ (TLV) item that has an 8-bit type, 8-bit length, and N-byte value.


During pairing, the device encodes data into one or more type-length-value items. To learn more, see ”5.15 Methods, Error
Codes, and TLV Values” (page 49).


**Table 14-1:** TLV8 Structure

|Name|Size in Bytes|Description|
|---|---|---|
|Type|1|Type of value.|
|Length|1|Number of value bytes, excluding type and length fields. 0 means there is no value data.|
|Value|Variable|Contains_ <_Length_>_ bytes of data for the value. May be empty if length is 0.|



**Table 14-2:** TLV8 Value Formats

|Name|Description|
|---|---|
|Bytes|Raw binary data.|
|Integer|Little endian integer. This must use the minimum number of bytes to encode the integer.|
|UTF-8|UTF-8 encoded string. This must not contain a NULL terminator (size is specified by the TLV length<br>field).|



14.1.1 TLV Rules


The following rules apply:


   - TLV items with unrecognized types must be silently ignored.


   - TLV item length describes the number of value bytes, excluding the type and length bytes. 0 is a valid length.


   - Values less than or equal to 255 bytes must be contained in a single TLV item and not fragmented.


   - Values larger than 255 bytes must be fragmented into multiple, TLV fragment items.


   - Each TLV fragment item must begin with an 8-bit type followed by an 8-bit length.


   - Each TLV fragment itemʼs type must be same.


   - Each TLV fragment itemʼs length must describe only that fragmentʼs portion of the value.


   - Each TLV fragment item must have a non-0 length.


   - TLV fragment items must be contiguous.


   - Only the last TLV fragment item in series of contiguous TLV fragment items may have non-255 byte length.


   - There may be multiple, separate TLV items of the same type if separated by a TLV item of a different type.


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


254


14. Appendix



14.1.2 TLV Examples


TLV Example 1 (2 small TLVs)

```
Byte 0: 0x06 (state)
Byte 1: 0x01 (1 byte value)
Byte 2: 0x03 (M3)
Byte 3: 0x01 (identifier)
Byte 4: 0x05 (5 byte value)
Byte 5: 0x68 (ASCII ’h’)
Byte 6: 0x65 (ASCII ’e’)
Byte 7: 0x6C (ASCII ’l’)
Byte 8: 0x6C (ASCII ’l’)
Byte 9: 0x6F (ASCII ’o’)
Total: 10 bytes

Raw hex dump:
00000000 07 01 03 01 05 68 65 6c 6c 6f |.....hello|
0000000a

```

TLV Example 2 (1 small TLV, 1 300-byte value splits into 2 TLVs, 1 small TLV)

```
Byte 0: 0x06 (state)
Byte 1: 0x01 (1 byte value)
Byte 2: 0x03 (M3)
Byte 3: 0x09 (certificate)
Byte 4: 0xFF (255 byte value)
Byte 5: 0x61 (ASCII ’a’)
... 254 more bytes containing 0x61 (ASCII ’a’)
Byte 260: 0x09 (certificate...continuation of previous TLV)
Byte 261: 0x2D (45 byte value)
Byte 262: 0x61 (ASCII ’a’)
... 44 more bytes containing 0x61 (ASCII ’a’)
Byte 307: 0x01 (identifier...new TLV item)
Byte 308: 0x05 (5 byte value)
Byte 309: 0x68 (ASCII ’h’)
Byte 310: 0x65 (ASCII ’e’)
Byte 311: 0x6C (ASCII ’l’)
Byte 312: 0x6C (ASCII ’l’)
Byte 313: 0x6F (ASCII ’o’)
Total: 314 bytes

Raw hex dump:
00000000 07 01 03 0a ff 61 61 61 |.....aaa|
00000008 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000010 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000018 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000020 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000028 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000030 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000038 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000040 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000048 61 61 61 61 61 61 61 61 |aaaaaaaa|

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


255


14. Appendix


```
00000050 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000058 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000060 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000068 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000070 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000078 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000080 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000088 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000090 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000098 61 61 61 61 61 61 61 61 |aaaaaaaa|
000000A0 61 61 61 61 61 61 61 61 |aaaaaaaa|
000000A8 61 61 61 61 61 61 61 61 |aaaaaaaa|
000000B0 61 61 61 61 61 61 61 61 |aaaaaaaa|
000000B8 61 61 61 61 61 61 61 61 |aaaaaaaa|
000000C0 61 61 61 61 61 61 61 61 |aaaaaaaa|
000000C8 61 61 61 61 61 61 61 61 |aaaaaaaa|
000000D0 61 61 61 61 61 61 61 61 |aaaaaaaa|
000000D8 61 61 61 61 61 61 61 61 |aaaaaaaa|
000000E0 61 61 61 61 61 61 61 61 |aaaaaaaa|
000000E8 61 61 61 61 61 61 61 61 |aaaaaaaa|
000000F0 61 61 61 61 61 61 61 61 |aaaaaaaa|
000000F8 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000100 61 61 61 61 0a 2d 61 61 |aaaa.-aa|
00000108 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000110 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000118 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000120 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000128 61 61 61 61 61 61 61 61 |aaaaaaaa|
00000130 61 61 61 01 05 68 65 6c |aaa..hel|
00000138 6c 6f |lo|

```

2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


256


### 15 Document Revision History

This chapter describes the changes to _HomeKit Accessory Protocol Specification_ from the previous revision.


Removed Content


Section 11.10 Testing IP Cameras


Updated Content


Section ”2.3.3 Characteristics” (page 22)


Section ”2.3.3.2 Additional Authorization Data” (page 23)


Section ”2.5.3.2 Bridges” (page 25)


Section ”3.2 General Requirements” (page 27).


Section ”3.4 Firmware Updates” (page 27)


Section ”3.5 Coalescing Requirements” (page 27)


Section ”5.6 Pair Setup” (page 34)


Section ”5.6.2 M2: Accessory - _>_ iOS Device – ‘SRP Start Responseʼ” (page 34)


Section ”5.6.4 M4: Accessory - _>_ iOS Device – ‘SRP Verify Responseʼ” (page 36)


Section ”5.11 Remove Pairing” (page 44)


Section ”6.2.3 TCP Requirements” (page 52)


Section ”6.2.6 General Requirements” (page 53)


Section ”6.4 Discovery” (page 57)


Section ”6.7.3 Writing a Characteristic with Write Response” (page 73)


Section ”6.7.6 Identify Routine” (page 76)


Section ”6.10 HomeKit Data Stream” (page 80)


Section ”6.11 Testing IP Accessories” (page 86)


Section ”7.2 Accessory Requirements” (page 88)


Section ”7.3.1 HAP Transactions and Procedures” (page 88)


Section ”8.1 Accessory Information” (page 134)


Section ”8.2 Air Purifier” (page 134)


Section ”8.13 Fan” (page 140)


Section ”8.18 Heater Cooler” (page 143)


Section ”8.19 Humidifier Dehumidifier” (page 144)


Section ”9.5 Administrator Only Access” (page 160)


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


257


15. Document Revision History



Section ”9.20 Cooling Threshold Temperature” (page 167)


Section ”9.32 Current Heating Cooling State” (page 173)


Section ”9.34 Current Relative Humidity” (page 174)


Section ”9.42 Heating Threshold Temperature” (page 178)


Section ”9.49 Is Configured” (page 182)


Section ”9.61 Mute” (page 188)


Section ”9.91 Selected RTP Stream Configuration” (page 204)


Section ”9.92 Setup Endpoints” (page 208)


Section ”9.104 Supported RTP Configuration” (page 218)


Section ”9.120 Target Relative Humidity” (page 231)


Section ”9.121 Target Temperature” (page 231)


Section ”9.127 Volume” (page 234)


Section ”11.1 Overview” (page 238)


Section ”11.9 Media Transport” (page 246)


New Content


Section ”4 Accessory Setup” (page 29)


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


258



Apple Inc.
Copyright © 2019 Apple Inc.
All rights reserved.


No part of this publication may be reproduced, stored in a retrieval system, or transmitted, in any form or by any means, mechanical, electronic, photocopying,
recording, or otherwise, without prior written permission of Apple Inc., with the following exceptions: Any person is hereby authorized to store documentation
on a single computer or device for personal use only and to print copies of documentation for personal use provided that the documentation contains Appleʼs
copyright notice.


No licenses, express or implied, are granted with respect to any of the technology described in this document. Apple retains all intellectual property rights
associated with the technology described in this document. This document is intended to be used in the development of solutions for Apple-branded products.


Apple Inc.
One Apple Park Way
Cupertino, CA 95014
408-996-1010


Apple is a trademark of Apple Inc., registered in the U.S. and other countries.


**APPLE MAKES NO WARRANTY OR REPRESENTATION, EITHER EXPRESS OR IMPLIED, WITH RESPECT TO THIS DOCUMENT, ITS QUALITY, ACCURACY,**
**MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE. AS A RESULT, THIS DOCUMENT IS PROVIDED ”AS IS,” AND YOU, THE READER, ARE**
**ASSUMING THE ENTIRE RISK AS TO ITS QUALITY AND ACCURACY.**


**IN NO EVENT WILL APPLE BE LIABLE FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES RESULTING FROM ANY DEFECT,**
**ERROR OR INACCURACY IN THIS DOCUMENT, even if advised of the possibility of such damages.**


**Some jurisdictions do not allow the exclusion of implied warranties or liability, so the above exclusion may not apply to you.**


2019-07-26 | Copyright © 2019 Apple Inc. All Rights Reserved.


259



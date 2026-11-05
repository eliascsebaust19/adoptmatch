param(
    [string]$apiUrl = "https://adoptmatch-api.onrender.com/api/v1",
    [string]$email = "shelter@adoptmatch.org",
    [string]$password = "shelter123456"
)

Write-Host "Authenticating shelter at $apiUrl/auth/login..."
$loginBody = @{
    email = $email
    password = $password
} | ConvertTo-Json

try {
    $loginRes = Invoke-RestMethod -Uri "$apiUrl/auth/login" -Method Post -ContentType "application/json" -Body $loginBody
    $token = $loginRes.access_token
    Write-Host "Authenticated successfully! Bearer token obtained."
} catch {
    Write-Error "Failed to authenticate with backend: $_"
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $token"
    "Accept" = "application/json"
    "Content-Type" = "application/json"
}

$pets = @(
    @{
        name = "Milo"
        species = "dog"
        breed = "Golden Retriever"
        age_months = 8
        gender = "male"
        size = "medium"
        vaccination_status = "Up to date"
        description = "Playful, friendly Golden Retriever puppy who loves fetching tennis balls and cuddling."
        location_city = "Banani, Dhaka"
        location_lat = 23.7937
        location_lng = 90.4066
        images = @("https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=800&q=80", "https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?auto=format&fit=crop&w=800&q=80")
    },
    @{
        name = "Luna"
        species = "cat"
        breed = "Persian Longhair"
        age_months = 18
        gender = "female"
        size = "small"
        vaccination_status = "Fully Vaccinated"
        description = "Calm and regal Persian cat with a silk coat. Prefers quiet apartments and gentle stroking."
        location_city = "Gulshan 2, Dhaka"
        location_lat = 23.7925
        location_lng = 90.4078
        images = @("https://images.unsplash.com/photo-1518791841217-8f162f1e1131?auto=format&fit=crop&w=800&q=80", "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=800&q=80")
    },
    @{
        name = "Rocky"
        species = "dog"
        breed = "German Shepherd"
        age_months = 24
        gender = "male"
        size = "large"
        vaccination_status = "Fully Vaccinated & Dewormed"
        description = "Loyal, intelligent, and highly alert German Shepherd. Excellent guard and family companion."
        location_city = "Uttara Sector 4, Dhaka"
        location_lat = 23.8759
        location_lng = 90.3795
        images = @("https://images.unsplash.com/photo-1589941013453-ec89f33b5e95?auto=format&fit=crop&w=800&q=80")
    },
    @{
        name = "Bella"
        species = "dog"
        breed = "Beagle"
        age_months = 11
        gender = "female"
        size = "small"
        vaccination_status = "Up to date"
        description = "Curious and energetic Beagle with a sweet temperament. Great with children and other pets."
        location_city = "Dhanmondi 27, Dhaka"
        location_lat = 23.7461
        location_lng = 90.3742
        images = @("https://images.unsplash.com/photo-1505628346881-b72b27e84530?auto=format&fit=crop&w=800&q=80")
    },
    @{
        name = "Simba"
        species = "cat"
        breed = "Ginger Tabby"
        age_months = 6
        gender = "male"
        size = "small"
        vaccination_status = "First Round Done"
        description = "Spunky little ginger kitten rescued from Mirpur. Loves climbing cat trees and purring loudly."
        location_city = "Mirpur DOHS, Dhaka"
        location_lat = 23.8223
        location_lng = 90.3654
        images = @("https://images.unsplash.com/photo-1574158622682-e40e69881006?auto=format&fit=crop&w=800&q=80")
    },
    @{
        name = "Charlie"
        species = "dog"
        breed = "Labrador Retriever"
        age_months = 15
        gender = "male"
        size = "medium"
        vaccination_status = "Fully Vaccinated"
        description = "Affectionate chocolate Lab who gets along with everyone. Well trained and loves walking outdoors."
        location_city = "Mohakhali DOHS, Dhaka"
        location_lat = 23.7808
        location_lng = 90.3987
        images = @("https://images.unsplash.com/photo-1579202673506-ca3ce28943ef?auto=format&fit=crop&w=800&q=80")
    },
    @{
        name = "Coco"
        species = "cat"
        breed = "Siamese"
        age_months = 10
        gender = "female"
        size = "small"
        vaccination_status = "Up to date"
        description = "Stunning blue-eyed Siamese beauty. Vocal, communicative, and loves sitting in your lap."
        location_city = "Bashundhara R/A, Dhaka"
        location_lat = 23.8151
        location_lng = 90.4255
        images = @("https://images.unsplash.com/photo-1513360309081-38f076278f1c?auto=format&fit=crop&w=800&q=80")
    },
    @{
        name = "Max"
        species = "dog"
        breed = "Siberian Husky"
        age_months = 20
        gender = "male"
        size = "large"
        vaccination_status = "Fully Vaccinated"
        description = "Majestic Husky with dual-colored eyes. High energy and perfect for an active owner."
        location_city = "Baridhara Diplomatic, Dhaka"
        location_lat = 23.7998
        location_lng = 90.4206
        images = @("https://images.unsplash.com/photo-1561037404-61cd46aa615b?auto=format&fit=crop&w=800&q=80")
    },
    @{
        name = "Oreo"
        species = "cat"
        breed = "Tuxedo Shorthair"
        age_months = 12
        gender = "male"
        size = "small"
        vaccination_status = "Up to date"
        description = "Classic black-and-white tuxedo gentleman. Calm, easygoing, and loves sunny window perches."
        location_city = "Lalmatia, Dhaka"
        location_lat = 23.7547
        location_lng = 90.3702
        images = @("https://images.unsplash.com/photo-1533738363-b7f9aef128ce?auto=format&fit=crop&w=800&q=80")
    },
    @{
        name = "Daisy"
        species = "dog"
        breed = "French Bulldog"
        age_months = 9
        gender = "female"
        size = "small"
        vaccination_status = "Up to date"
        description = "Gentle bat-eared Frenchie. Loves sleeping on rugs, snorting with joy, and greeting visitors."
        location_city = "Shantinagar, Dhaka"
        location_lat = 23.7410
        location_lng = 90.4131
        images = @("https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=800&q=80")
    },
    @{
        name = "Rio"
        species = "other"
        breed = "Blue-and-Gold Macaw"
        age_months = 24
        gender = "male"
        size = "medium"
        vaccination_status = "Avian Vet Verified"
        description = "Intelligent and colorful macaw who can mimic greetings and whistle tunes. Rescued bird."
        location_city = "Elephant Road, Dhaka"
        location_lat = 23.7380
        location_lng = 90.3850
        images = @("https://images.unsplash.com/photo-1552728089-57bdde30beb3?auto=format&fit=crop&w=800&q=80")
    },
    @{
        name = "Bunny Hop"
        species = "other"
        breed = "Holland Lop Rabbit"
        age_months = 7
        gender = "female"
        size = "small"
        vaccination_status = "Vaccinated"
        description = "Fluffy Holland Lop with floppy ears. Extremely quiet, litter-box trained, and adores fresh greens."
        location_city = "Uttara Sector 11, Dhaka"
        location_lat = 23.8710
        location_lng = 90.3950
        images = @("https://images.unsplash.com/photo-1585110396000-c9ffd4e4b308?auto=format&fit=crop&w=800&q=80")
    }
)

$count = 0
foreach ($p in $pets) {
    $body = $p | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$apiUrl/pets" -Method Post -Headers $headers -ContentType "application/json" -Body $body
        $count++
        Write-Host "[$count/12] Successfully created: $($p.name) ($($p.breed)) in $($p.location_city)"
    } catch {
        Write-Warning "Skipped or failed creating $($p.name): $_"
    }
}

Write-Host "Seeding complete: $count pets posted to $apiUrl"

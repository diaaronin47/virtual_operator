print("hellooo shaimaa")

import cv2
import numpy as np

def load_and_split_channels(image_path):
    """Load an image and split it into R, G, B channels."""
    img = cv2.imread(image_path)
    if img is None:
        print(f"Failed to load image: {image_path}")
        return None
    return cv2.split(img)  # Returns (B, G, R)

def extract_orb_features(channel):
    """Extract ORB keypoints and descriptors."""
    orb = cv2.ORB_create(nfeatures=500)  # Adjust nfeatures for speed vs accuracy
    keypoints, descriptors = orb.detectAndCompute(channel, None)
    return keypoints, descriptors

def filter_matches_ransac(kp1, kp2, matches):
    """Apply RANSAC filtering to remove outliers."""
    if len(matches) < 4:
        return [], 0

    pts1 = np.float32([kp1[m.queryIdx].pt for m in matches]).reshape(-1, 1, 2)
    pts2 = np.float32([kp2[m.trainIdx].pt for m in matches]).reshape(-1, 1, 2)

    H, mask = cv2.findHomography(pts1, pts2, cv2.RANSAC, 6.0)
    if H is None or mask is None:
        return [], 0

    inlier_matches = [matches[i] for i in range(len(mask)) if mask[i]]
    return inlier_matches, len(inlier_matches)

def compare_images(image1_path, image2_path):
    """Compare images using ORB with RGB channels and RANSAC filtering."""
    img1_channels = load_and_split_channels(image1_path)
    img2_channels = load_and_split_channels(image2_path)

    if img1_channels is None or img2_channels is None:
        return None, 0.0

    bf = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)
    total_inliers = 0
    total_keypoints = 0
    all_matches = []
    keypoints1_all, keypoints2_all = [], []

    for i in range(3):  # Process R, G, B channels
        kp1, des1 = extract_orb_features(img1_channels[i])
        kp2, des2 = extract_orb_features(img2_channels[i])

        if des1 is None or des2 is None:
            continue

        matches = bf.match(des1, des2)
        matches = sorted(matches, key=lambda x: x.distance)  # Sort by quality

        inlier_matches, num_inliers = filter_matches_ransac(kp1, kp2, matches)

        all_matches.extend(inlier_matches)
        keypoints1_all.extend(kp1)
        keypoints2_all.extend(kp2)
        total_inliers += num_inliers
        total_keypoints += len(kp1) + len(kp2)

    if total_keypoints == 0 or total_inliers == 0:
        return None, 0.0

    similarity_percentage = (total_inliers / (total_keypoints / 2)) * 100

    # Draw matches
    img1 = cv2.imread(image1_path)
    img2 = cv2.imread(image2_path)
    img_matches = cv2.drawMatches(img1, keypoints1_all, img2, keypoints2_all, all_matches[:30], None)

    result_image_path = 'image_comparison.png'
    cv2.imwrite(result_image_path, img_matches)

    return result_image_path, similarity_percentage

def display_similarities(image1_path, image2_path):
    result_image_path, similarity_percentage = compare_images(image1_path, image2_path)
    
    if result_image_path is None:
        print("Image comparison failed.")
        return

    print(f"Image 1 is {similarity_percentage:.2f}% similar to Image 2.")
    result_img = cv2.imread(result_image_path)
    cv2.imshow('Similarities', result_img)
    cv2.waitKey(0)
    cv2.destroyAllWindows()

# Example usage:
image1_path = 'C:/Users/hamdydia/OneDrive - Electrolux/Desktop/thjq4e6jhtq4e.png'

image2_path = 'C:/Users/hamdydia/OneDrive - Electrolux/Desktop/thjq4e6jhtq4e.png'

display_similarities(image1_path, image2_path)

//
//  Created by Jesse Squires
//  http://www.hexedbits.com
//
//
//  Documentation
//  http://cocoadocs.org/docsets/JSQMessagesViewController
//
//
//  GitHub
//  https://github.com/jessesquires/JSQMessagesViewController
//
//
//  License
//  Copyright (c) 2014 Jesse Squires
//  Released under an MIT license: http://opensource.org/licenses/MIT
//
//
//  Converted to Swift by Tung Thanh Nguyen
//  Copyright © 2016 Tung Thanh Nguyen.
//  Released under an MIT license: http://opensource.org/licenses/MIT
//
//  GitHub
//  https://github.com/tungthanhnguyen/CSMessagesViewController
//

import CSSystemSoundPlayer
import UIKit

class ViewController: UIViewController
{
	let soundPlayer = CSSystemSoundPlayer.sharedPlayer
	
	@IBOutlet weak var soundSwitch: UISwitch!

	override func viewDidLoad()
	{
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		
		soundSwitch.setOn(soundPlayer.isOn, animated: true)
	}

	override func didReceiveMemoryWarning()
	{
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	@IBAction func playSystemSound(_ sender: AnyObject)
	{
		soundPlayer.playSoundWith(fileName: "Basso", extension: kCSSystemSoundTypeAIF,
			completionBlock:
			{
				NSLog("Sound finished playing. Executing completion block...")
				
				self.soundPlayer.playAlertSoundWith(fileName: "Funk", extension: kCSSystemSoundTypeAIFF)
			}
		)
	}

	@IBAction func playAlertSound(_ sender: AnyObject)
	{
		soundPlayer.playAlertSoundWith(fileName: "Funk", extension: kCSSystemSoundTypeAIFF)
	}
	
	@IBAction func playVibration(_ sender: AnyObject)
	{
		soundPlayer.playVibrateSound()
	}
	
	@IBAction func playLongSound(_ sender: AnyObject)
	{
		NSLog("Playing long sound...")
		
		soundPlayer.playSoundWith(fileName: "BalladPiano", extension: kCSSystemSoundTypeCAF,
			completionBlock:
			{
				NSLog("Long sound complete!");
			}
		)
	}
	
	@IBAction func stopAllSounds(_ sender: AnyObject)
	{
		soundPlayer.stopAllSounds()
	}
	
	@IBAction func toogleSwitch(_ sender: UISwitch)
	{
		soundPlayer.toggleSoundPlayerOn(sender.isOn)
	}
}

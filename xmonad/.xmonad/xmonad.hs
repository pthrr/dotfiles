import XMonad
import XMonad.Hooks.ManageDocks
import XMonad.Util.Run
import XMonad.Hooks.DynamicLog
import XMonad.Util.CustomKeys
import XMonad.Util.EZConfig
import Graphics.X11.ExtraTypes.XF86
import XMonad.Actions.CycleWS

main = do
xmproc <- spawnPipe "xmobar"
xmonad $ def
  { terminal = "xterm"
  , manageHook = manageDocks <+> manageHook def
  , layoutHook = avoidStruts $ layoutHook def
  , focusFollowsMouse = False
  , handleEventHook = handleEventHook def <+> docksEventHook
  , logHook = dynamicLogWithPP $ def
    { ppOutput = hPutStrLn xmproc
    , ppOrder = \(ws:_:t:_) -> [ws,t]
    }
  , borderWidth = 2
  }
  `additionalKeys`
  [ ((mod1Mask, xK_p), spawn "exe=`dmenu_path | /home/pthrr/.cabal/bin/yeganesh -- -b -fn \"xft:DejaVu Sans Mono:size=10\"` && eval \"exec $exe\"")
  , ((mod1Mask, xK_s), spawn "slock")
  , ((0, xF86XK_MonBrightnessUp), spawn "xbacklight +10")
  , ((0, xF86XK_MonBrightnessDown), spawn "xbacklight -10")
  , ((0, xF86XK_AudioMute), spawn "pactl set-sink-mute @DEFAULT_SINK@ toggle")
  , ((0, xF86XK_AudioMicMute), spawn "pactl set-source-mute @DEFAULT_SOURCE@ toggle")
  , ((0, xF86XK_AudioLowerVolume), spawn "pactl set-sink-volume @DEFAULT_SINK@ -10%")
  , ((0, xF86XK_AudioRaiseVolume), spawn "pactl set-sink-volume @DEFAULT_SINK@ +10%")
  , ((mod1Mask, xK_Right), nextWS)
  , ((mod1Mask, xK_Left), prevWS)
  , ((mod1Mask .|. shiftMask, xK_Right), shiftToNext)
  , ((mod1Mask .|. shiftMask, xK_Left), shiftToPrev)
  , ((mod1Mask, xK_Up), nextScreen)
  , ((mod1Mask, xK_Down), prevScreen)
  , ((mod1Mask .|. shiftMask, xK_Up), shiftNextScreen)
  , ((mod1Mask .|. shiftMask, xK_Down), shiftPrevScreen)
  , ((mod1Mask, xK_z), toggleWS)
  ]

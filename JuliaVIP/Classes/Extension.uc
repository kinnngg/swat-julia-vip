class Extension extends Julia.Extension
 implements IInterested_GameEvent_PawnArrested,
            Julia.InterestedInMissionStarted,
            Julia.InterestedInPlayerVIPSet;

/**
 * Copyright (c) 2014 Sergei Khoroshilov <kh.sergei@gmail.com>
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

/**
 * Current extra time addition counter
 * @type int
 */
var protected int ExtraRoundTimeCount;

/**
 * Extra round time added in case the VIP is arrested in the last 120 seconds
 * Setting the property to zero disabled this feature
 * @type float
 */
var config float ExtraRoundTime;

/**
 * Limit the maximum number of extra time additions within a round
 * @type float
 */
var config int ExtraRoundTimeLimit;

/**
 * Space separated vip custom health levels
 * @type string
 */
var config string VIPCustomHealth;

/**
 * Check whether this is a COOP server
 * 
 * @return  void
 */
public function BeginPlay()
{
    Super.BeginPlay();

    if (self.Core.GetServer().GetGameType() != MPM_VIPEscort)
    {
        log(self $ ": refused to operate on a non-VIP server");
        self.Destroy();
        return;
    }

    SwatGameInfo(Level.Game).GameEvents.PawnArrested.Register(self);
    self.Core.RegisterInterestedInMissionStarted(self);
    self.Core.RegisterInterestedInPlayerVIPSet(self);
}

/**
 * Attempt to detect a VIP arrest
 * 
 * @param   class'Pawn' Pawn
 * @param   class'Pawn' Arrester
 * @return  void
 */
public function OnPawnArrested(Pawn Pawn, Pawn Arrester)
{
    local Player Arrestee;

    if (!Pawn.IsA('SwatPlayer'))
    {
        return;
    }

    Arrestee = self.Core.GetServer().GetPlayerByPawn(Pawn);

    if (Arrestee == None)
    {
        return;
    }

    // If the arrested player is the VIP, attempt to add extra time
    if (Arrestee.IsVIP())
    {
        self.AddExtraRoundTime();
    }
}

/**
 * Check whether the VIP's health has to be altered upon a VIP assignment
 * 
 * @see  Julia.InterestedInPlayerVIPSet.OnPlayerVIPSet
 */
public function OnPlayerVIPSet(Julia.Player Player)
{
    self.SetVIPCustomHealth(Player);
}

/**
 * Reset extra time counter upon a round start
 * 
 * @see  Julia.InterestedInMissionStarted.OnMissionStarted
 */
public function OnMissionStarted()
{
    self.ExtraRoundTimeCount = 0;
}

/**
 * Attempt to add extra round time
 * 
 * @return  void
 */
protected function AddExtraRoundTime()
{
    // The feature is disabled
    if (self.ExtraRoundTimeLimit <= 0 || self.ExtraRoundTime < 120)
    {
        log(self $ ": extra time is disabled");
        return;
    }
    // Check whether extra time is needed at all
    if (
        SwatGameReplicationInfo(Level.Game.GameReplicationInfo).RoundTime > 120 ||
        SwatGameReplicationInfo(Level.Game.GameReplicationInfo).RoundTime <= 1  ||
        SwatGameReplicationInfo(Level.Game.GameReplicationInfo).ServerCountdownTime <= 1
    )
    {
        return;
    }
    // Extra time addition count has exceeded the limit
    if (self.ExtraRoundTimeCount >= self.ExtraRoundTimeLimit)
    {
        log(self $ ": reached extra time limit");
        return;
    }

    SwatGameReplicationInfo(Level.Game.GameReplicationInfo).ServerCountdownTime += self.ExtraRoundTime;
    self.ExtraRoundTimeCount++;
    
    class'Utils.LevelUtils'.static.TellAll(
        Level,
        self.Locale.Translate("ExtraRoundTimeAdded", int(self.ExtraRoundTime)),
        self.Locale.Translate("MessageColor")
    );
}

/**
 * Attempt to set custom health level for the VIP Player
 * 
 * @param   class'Julia.Player' Player
 * @return  void
 */
protected function SetVIPCustomHealth(Julia.Player Player)
{
    local int i;
    local int NewHealth;
    local array<string> CustomLevels;

    if (!Player.IsVIP())
    {
        return;
    }

    // Attempt to get a list of space separated health levels
    CustomLevels = class'Utils.StringUtils'.static.Part(self.VIPCustomHealth, " ");

    // Remove non-digit values
    for (i = CustomLevels.Length-1; i >= 0; i--)
    {
        if (!class'Utils.StringUtils'.static.IsDigit(CustomLevels[i]))
        {
            CustomLevels.Remove(i, 1);
        }
    }
    // Get the only defined value
    if (CustomLevels.Length == 1)
    {
        NewHealth = int(CustomLevels[0]);
    }
    // Pick a random one
    else if (CustomLevels.Length > 1)
    {
        NewHealth = int(class'Utils.ArrayUtils'.static.Random(CustomLevels));
    }
    else
    {
        return;
    }

    // Set new health level
    if (NewHealth > 0 && NewHealth != 100)
    {
        log(self $ ": setting VIP custom health: " $ NewHealth);

        Player.GetPawn().Health = NewHealth;

        class'Utils.LevelUtils'.static.TellAll(
            Level,
            self.Locale.Translate("CustomHealthLevelSet", int(self.ExtraRoundTime)),
            self.Locale.Translate("MessageColor")
        );
    }
}

event Destroyed()
{
    if (self.Core != None)
    {
        self.Core.UnregisterInterestedInMissionStarted(self);
        self.Core.UnregisterInterestedInPlayerVIPSet(self);
    }

    SwatGameInfo(Level.Game).GameEvents.PawnArrested.UnRegister(self);

    Super.Destroyed();
}

defaultproperties
{
    Title="Julia/VIP";
    Version="1.0.0";
    LocaleClass=class'Locale';

    VIPCustomHealth="100";
    ExtraRoundTime=0.0;
    ExtraRoundTimeLimit=0;
}

/* vim: set ft=java: */
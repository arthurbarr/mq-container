/*
© Copyright IBM Corporation 2017, 2019

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
package main

import (
	"io"
	"os"
	"runtime"
	"syscall"

	"github.com/ibm-messaging/mq-container/internal/command"
)

func createMQDirectory(path string) error {
	fi, err := os.Stat(path)
	if err != nil {
		if os.IsNotExist(err) {
			// #nosec G301
			err = os.MkdirAll(path, 0755)
			if err != nil {
				return err
			}
		} else {
			return err
		}
	}
	fi, err = os.Stat(path)
	if err != nil {
		return err
	}
	sys := fi.Sys()
	if sys != nil && runtime.GOOS == "linux" {
		stat := sys.(*syscall.Stat_t)
		mqmUID, mqmGID, err := command.LookupMQM()
		if err != nil {
			return err
		}
		log.Debugf("mqm user is %v (%v)", mqmUID, mqmGID)
		if int(stat.Uid) != mqmUID || int(stat.Gid) != mqmGID {
			err = os.Chown(path, mqmUID, mqmGID)
			if err != nil {
				log.Printf("Error: Unable to change ownership of %v", path)
				return err
			}
		}
	}
	return nil
}

// CopyFile copies the specified file
func CopyFile(src, dest string) error {
	log.Debugf("Copying file %v to %v", src, dest)
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.OpenFile(dest, os.O_CREATE|os.O_WRONLY, 0770)
	defer out.Close()

	_, err = io.Copy(out, in)
	if err != nil {
		return err
	}
	err = out.Close()
	return err
}
